import cors from "@fastify/cors";
import rateLimit from "@fastify/rate-limit";
import "dotenv/config";
import Fastify from "fastify";
import type { FastifyInstance } from "fastify";
import { randomUUID } from "node:crypto";

import {
  type AppConfig,
  loadConfig,
  parseAllowedOrigins,
} from "./config.js";
import {
  createRoomRequestSchema,
  entryFeeTierSchema,
  type RoomRecord,
} from "./schemas/rooms.js";
import { RoomsStore } from "./storage.js";

const RATE_LIMIT_WINDOW = "1 minute";
const RATE_LIMITS = {
  createRoom: 30,
  getRoom: 120,
  health: 120,
} as const;
const LOG_REDACT_PATHS = [
  "req.headers.authorization",
  "req.headers.Authorization",
];

type Deps = {
  fetchImpl?: typeof fetch;
  logger?: boolean;
  now?: () => string;
  store?: RoomsStore;
};

type AuthWhoamiResponse = {
  sub?: string;
};

type PublicValidationDetail = {
  field: string;
  message: string;
};

const ENTRY_FEE_AMOUNTS: Record<(typeof entryFeeTierSchema)["_type"], string> = {
  cheap: "100000000000000000",
  average: "500000000000000000",
  deluxe: "1000000000000000000",
};

async function verifyBearerToken(
  config: AppConfig,
  authorizationHeader: string | undefined,
  fetchImpl: typeof fetch,
): Promise<
  | { ok: true; subject: string }
  | { ok: false; status: number; body: Record<string, unknown> }
> {
  if (!authorizationHeader || !authorizationHeader.toLowerCase().startsWith("bearer ")) {
    return {
      ok: false,
      status: 401,
      body: { error: "missing_token" },
    };
  }

  let response: Response;
  try {
    response = await fetchImpl(new URL(config.AUTH_VERIFY_PATH, config.AUTH_BASE_URL), {
      headers: {
        Authorization: authorizationHeader,
      },
    });
  } catch {
    return {
      ok: false,
      status: 502,
      body: { error: "auth_service_unavailable" },
    };
  }

  if (!response.ok) {
    return {
      ok: false,
      status: 401,
      body: { error: "unauthorized" },
    };
  }

  const payload = (await response.json()) as AuthWhoamiResponse;
  if (typeof payload.sub !== "string" || payload.sub.length === 0) {
    return {
      ok: false,
      status: 502,
      body: { error: "invalid_auth_response" },
    };
  }

  return {
    ok: true,
    subject: payload.sub,
  };
}

function toPublicRoom(room: RoomRecord): Omit<RoomRecord, "created_by"> {
  const { created_by: _createdBy, ...publicRoom } = room;
  return publicRoom;
}

function formatValidationErrors(
  issues: ReadonlyArray<{ code: string; path: Array<string | number>; message: string }>,
): PublicValidationDetail[] {
  return issues.map((issue) => {
    if (issue.code === "invalid_union" && issue.path.length === 1 && issue.path[0] === "player_count") {
      return {
        field: "player_count",
        message: "must be one of 2, 3, or 4",
      };
    }

    return {
      field: issue.path.length > 0 ? issue.path.join(".") : "request",
      message: issue.message,
    };
  });
}

export async function buildServer(
  config: AppConfig,
  deps: Deps = {},
): Promise<FastifyInstance> {
  const logger =
    deps.logger === false
      ? false
      : {
          redact: {
            paths: LOG_REDACT_PATHS,
            censor: "[redacted]",
          },
        };
  const app = Fastify({
    logger,
    bodyLimit: 16 * 1024,
  });
  const fetchImpl = deps.fetchImpl ?? fetch;
  const now = deps.now ?? (() => new Date().toISOString());
  const store = deps.store ?? new RoomsStore(config.ROOMS_DATA_FILE);

  await store.initialize();

  app.register(cors, {
    origin: parseAllowedOrigins(config),
  });
  await app.register(rateLimit, {
    global: false,
    addHeadersOnExceeding: {
      "x-ratelimit-limit": true,
      "x-ratelimit-remaining": true,
      "x-ratelimit-reset": true,
    },
  });

  const createRoomRateLimit = app.rateLimit({
    max: RATE_LIMITS.createRoom,
    timeWindow: RATE_LIMIT_WINDOW,
  });
  const getRoomRateLimit = app.rateLimit({
    max: RATE_LIMITS.getRoom,
    timeWindow: RATE_LIMIT_WINDOW,
  });
  const healthRateLimit = app.rateLimit({
    max: RATE_LIMITS.health,
    timeWindow: RATE_LIMIT_WINDOW,
  });

  app.get(
    "/healthz",
    {
      preHandler: healthRateLimit,
    },
    async (_request, reply) => reply.send({ ok: true }),
  );

  app.post(
    "/v0/rooms",
    {
      preHandler: createRoomRateLimit,
    },
    async (request, reply) => {
      const parsed = createRoomRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply
          .status(400)
          .send({
            error: "bad_request",
            details: formatValidationErrors(parsed.error.errors),
          });
      }

      const authResult = await verifyBearerToken(
        config,
        request.headers.authorization,
        fetchImpl,
      );
      if (!authResult.ok) {
        return reply.status(authResult.status).send(authResult.body);
      }

      const room: RoomRecord = {
        game_id: randomUUID(),
        created_by: authResult.subject,
        creator_display_name: parsed.data.creator_display_name,
        entry_fee_tier: parsed.data.entry_fee_tier,
        entry_fee_amount: ENTRY_FEE_AMOUNTS[parsed.data.entry_fee_tier],
        player_count: parsed.data.player_count,
        ...(parsed.data.experimental === undefined
          ? {}
          : { experimental: parsed.data.experimental }),
        created_at: now(),
      };
      await store.createRoom(room);
      return reply.status(201).send(room);
    },
  );

  app.get(
    "/v0/rooms/:gameId",
    {
      preHandler: getRoomRateLimit,
    },
    async (request, reply) => {
      const params = request.params as { gameId?: string };
      const gameId = params.gameId ?? "";
      const room = store.getRoom(gameId);
      if (!room) {
        return reply.status(404).send({ error: "room_not_found" });
      }
      return reply.send(toPublicRoom(room));
    },
  );

  return app;
}
