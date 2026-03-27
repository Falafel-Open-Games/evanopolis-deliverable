import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

import { afterEach, describe, expect, it } from "vitest";

import { buildServer } from "../src/server.js";
import { RoomsStore } from "../src/storage.js";

describe("rooms-api", () => {
  const apps: Array<{ close: () => Promise<void> }> = [];
  const tempDirectories: string[] = [];

  afterEach(async () => {
    while (apps.length > 0) {
      const app = apps.pop();
      if (app) {
        await app.close();
      }
    }

    while (tempDirectories.length > 0) {
      const directory = tempDirectories.pop();
      if (directory) {
        await rm(directory, { recursive: true, force: true });
      }
    }
  });

  it("creates a room for an authenticated caller", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
        now: () => "2026-03-17T12:00:00.000Z",
        fetchImpl: async () =>
          new Response(JSON.stringify({ sub: "0xabc" }), {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }),
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "POST",
      url: "/v0/rooms",
      headers: {
        authorization: "Bearer good-token",
      },
      payload: {
        creator_display_name: "Falafel Host",
        entry_fee_tier: "average",
        player_count: 4,
        experimental: {
          board_size: 30,
        },
      },
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      created_by: "0xabc",
      creator_display_name: "Falafel Host",
      entry_fee_tier: "average",
      entry_fee_amount: "500000000000000000",
      player_count: 4,
      experimental: {
        board_size: 30,
      },
      created_at: "2026-03-17T12:00:00.000Z",
    });
  });

  it("rejects room creation without a bearer token", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "POST",
      url: "/v0/rooms",
      payload: {
        creator_display_name: "Falafel Host",
        entry_fee_tier: "average",
        player_count: 4,
      },
    });

    expect(response.statusCode).toBe(401);
    expect(response.json()).toEqual({
      error: "missing_token",
    });
  });

  it("rejects invalid room payloads", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
        fetchImpl: async () =>
          new Response(JSON.stringify({ sub: "0xabc" }), {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }),
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "POST",
      url: "/v0/rooms",
      headers: {
        authorization: "Bearer good-token",
      },
      payload: {
        creator_display_name: "Falafel Host",
        entry_fee_tier: "average",
        player_count: 5,
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "bad_request",
      details: [
        {
          field: "player_count",
          message: "must be one of 2, 3, or 4",
        },
      ],
    });
  });

  it("rejects blank creator display names", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
        fetchImpl: async () =>
          new Response(JSON.stringify({ sub: "0xabc" }), {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }),
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "POST",
      url: "/v0/rooms",
      headers: {
        authorization: "Bearer good-token",
      },
      payload: {
        creator_display_name: "   ",
        entry_fee_tier: "average",
        player_count: 4,
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "bad_request",
      details: [
        {
          field: "creator_display_name",
          message: "String must contain at least 1 character(s)",
        },
      ],
    });
  });

  it("rejects creator display names longer than 32 characters", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
        fetchImpl: async () =>
          new Response(JSON.stringify({ sub: "0xabc" }), {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }),
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "POST",
      url: "/v0/rooms",
      headers: {
        authorization: "Bearer good-token",
      },
      payload: {
        creator_display_name: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        entry_fee_tier: "average",
        player_count: 4,
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "bad_request",
      details: [
        {
          field: "creator_display_name",
          message: "String must contain at most 32 character(s)",
        },
      ],
    });
  });

  it("returns the public room definition without created_by", async () => {
    const store = new RoomsStore();
    await store.createRoom({
      game_id: "550e8400-e29b-41d4-a716-446655440000",
      created_by: "0xabc",
      creator_display_name: "Falafel Host",
      entry_fee_tier: "cheap",
      entry_fee_amount: "100000000000000000",
      player_count: 3,
      experimental: {
        turn_duration_seconds: 60,
      },
      created_at: "2026-03-17T12:00:00.000Z",
    });
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store,
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "GET",
      url: "/v0/rooms/550e8400-e29b-41d4-a716-446655440000",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      game_id: "550e8400-e29b-41d4-a716-446655440000",
      creator_display_name: "Falafel Host",
      entry_fee_tier: "cheap",
      entry_fee_amount: "100000000000000000",
      player_count: 3,
      experimental: {
        turn_duration_seconds: 60,
      },
      created_at: "2026-03-17T12:00:00.000Z",
    });
  });

  it("skips incompatible legacy room records from persisted storage", async () => {
    const directory = await mkdtemp(join(tmpdir(), "rooms-api-"));
    tempDirectories.push(directory);
    const roomsDataFile = join(directory, "rooms.json");

    await writeFile(
      roomsDataFile,
      JSON.stringify([
        {
          game_id: "11111111-1111-4111-8111-111111111111",
          created_by: "0xlegacy",
          player_count: 2,
          created_at: "2026-03-17T11:00:00.000Z",
        },
        {
          game_id: "550e8400-e29b-41d4-a716-446655440000",
          created_by: "0xabc",
          creator_display_name: "Falafel Host",
          entry_fee_tier: "cheap",
          entry_fee_amount: "100000000000000000",
          player_count: 3,
          created_at: "2026-03-17T12:00:00.000Z",
        },
      ]),
    );

    const store = new RoomsStore(roomsDataFile);

    await expect(store.initialize()).resolves.toBeUndefined();
    expect(store.getRoom("11111111-1111-4111-8111-111111111111")).toBeNull();
    expect(store.getRoom("550e8400-e29b-41d4-a716-446655440000")).toMatchObject({
      creator_display_name: "Falafel Host",
      entry_fee_tier: "cheap",
      entry_fee_amount: "100000000000000000",
    });
  });

  it("returns 404 for missing rooms", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
      },
    );
    apps.push(app);

    const response = await app.inject({
      method: "GET",
      url: "/v0/rooms/missing-room",
    });

    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual({
      error: "room_not_found",
    });
  });

  it("rate limits repeated room creation attempts", async () => {
    const app = await buildServer(
      {
        PORT: 3001,
        AUTH_BASE_URL: "http://auth.local",
        AUTH_VERIFY_PATH: "/whoami",
        ALLOWED_ORIGINS: "",
        ROOMS_DATA_FILE: "",
      },
      {
        logger: false,
        store: new RoomsStore(),
        fetchImpl: async () =>
          new Response(JSON.stringify({ sub: "0xabc" }), {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }),
      },
    );
    apps.push(app);

    for (let index = 0; index < 30; index += 1) {
      const response = await app.inject({
        method: "POST",
        url: "/v0/rooms",
        headers: {
          authorization: "Bearer good-token",
          "x-forwarded-for": "203.0.113.10",
        },
        payload: {
          creator_display_name: "Falafel Host",
          entry_fee_tier: "average",
          player_count: 2,
        },
      });
      expect(response.statusCode).toBe(201);
    }

    const limited = await app.inject({
      method: "POST",
      url: "/v0/rooms",
      headers: {
        authorization: "Bearer good-token",
        "x-forwarded-for": "203.0.113.10",
      },
      payload: {
        creator_display_name: "Falafel Host",
        entry_fee_tier: "average",
        player_count: 2,
      },
    });

    expect(limited.statusCode).toBe(429);
  });
});
