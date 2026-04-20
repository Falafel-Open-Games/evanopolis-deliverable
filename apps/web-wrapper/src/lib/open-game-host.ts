import type { LaunchPayload } from "./launch";

export const OPEN_GAME_HOST_PROTOCOL = "open-game-host";
export const OPEN_GAME_HOST_VERSION = 1;

export type OpenGameHostClientReadyMessage = {
  protocol: typeof OPEN_GAME_HOST_PROTOCOL;
  version: typeof OPEN_GAME_HOST_VERSION;
  type: "client_ready";
};

export type OpenGameHostLaunchPayloadMessage = {
  protocol: typeof OPEN_GAME_HOST_PROTOCOL;
  version: typeof OPEN_GAME_HOST_VERSION;
  type: "launch_payload";
  payload: LaunchPayload;
};

export type OpenGameHostLaunchMissingMessage = {
  protocol: typeof OPEN_GAME_HOST_PROTOCOL;
  version: typeof OPEN_GAME_HOST_VERSION;
  type: "launch_missing";
  reason: string;
};

export type OpenGameHostMessage =
  | OpenGameHostClientReadyMessage
  | OpenGameHostLaunchPayloadMessage
  | OpenGameHostLaunchMissingMessage;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function parseRawMessage(value: unknown): unknown {
  if (typeof value !== "string") {
    return value;
  }

  try {
    return JSON.parse(value) as unknown;
  } catch {
    return null;
  }
}

export function parseOpenGameHostMessage(
  value: unknown,
): OpenGameHostMessage | null {
  const parsed = parseRawMessage(value);
  if (!isRecord(parsed)) {
    return null;
  }

  if (parsed.protocol !== OPEN_GAME_HOST_PROTOCOL) {
    return null;
  }

  if (parsed.version !== OPEN_GAME_HOST_VERSION) {
    return null;
  }

  const type = parsed.type;
  if (type === "client_ready") {
    return {
      protocol: OPEN_GAME_HOST_PROTOCOL,
      version: OPEN_GAME_HOST_VERSION,
      type,
    };
  }

  if (type === "launch_missing") {
    const reason =
      typeof parsed.reason === "string" && parsed.reason.trim().length > 0
        ? parsed.reason
        : "missing_launch_payload";
    return {
      protocol: OPEN_GAME_HOST_PROTOCOL,
      version: OPEN_GAME_HOST_VERSION,
      type,
      reason,
    };
  }

  if (type !== "launch_payload") {
    return null;
  }

  if (!isRecord(parsed.payload)) {
    return null;
  }

  const token = parsed.payload.token;
  const gameId = parsed.payload.gameId;
  const gameServerUrl = parsed.payload.gameServerUrl;
  const playerAddress = parsed.payload.playerAddress;

  if (
    typeof token !== "string" ||
    typeof gameId !== "string" ||
    typeof gameServerUrl !== "string" ||
    typeof playerAddress !== "string"
  ) {
    return null;
  }

  return {
    protocol: OPEN_GAME_HOST_PROTOCOL,
    version: OPEN_GAME_HOST_VERSION,
    type,
    payload: {
      token,
      gameId,
      gameServerUrl,
      playerAddress,
    },
  };
}

export function buildLaunchPayloadMessage(
  payload: LaunchPayload,
): OpenGameHostLaunchPayloadMessage {
  return {
    protocol: OPEN_GAME_HOST_PROTOCOL,
    version: OPEN_GAME_HOST_VERSION,
    type: "launch_payload",
    payload,
  };
}

export function buildLaunchMissingMessage(
  reason: string,
): OpenGameHostLaunchMissingMessage {
  return {
    protocol: OPEN_GAME_HOST_PROTOCOL,
    version: OPEN_GAME_HOST_VERSION,
    type: "launch_missing",
    reason,
  };
}
