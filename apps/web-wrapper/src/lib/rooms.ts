import type { RuntimeConfig } from "./runtime-config";

export type EntryFeeTier = "cheap" | "average" | "deluxe";

export type CreatedRoom = {
  gameId: string;
  createdBy: string;
  entryFeeTier: EntryFeeTier;
  entryFeeAmount: string;
  playerCount: number;
  createdAt: string;
};

export type PublicRoom = {
  gameId: string;
  creatorDisplayName: string;
  entryFeeTier: EntryFeeTier;
  entryFeeAmount: string;
  playerCount: number;
  createdAt: string;
};

type CreateRoomResponse = {
  game_id: string;
  created_by: string;
  entry_fee_tier: EntryFeeTier;
  entry_fee_amount: string;
  player_count: number;
  created_at: string;
};

type PublicRoomResponse = {
  game_id: string;
  creator_display_name: string;
  entry_fee_tier: EntryFeeTier;
  entry_fee_amount: string;
  player_count: number;
  created_at: string;
};

export function formatEntryFeeLabel(entryFeeTier: EntryFeeTier): string {
  switch (entryFeeTier) {
    case "cheap":
      return "0.10 TRT";
    case "average":
      return "0.50 TRT";
    case "deluxe":
      return "1.00 TRT";
  }
}

function normalizeBaseUrl(url: string): string {
  return url.trim().replace(/\/$/, "");
}

export async function createRoom(
  runtimeConfig: RuntimeConfig,
  authToken: string,
  creatorDisplayName: string,
  entryFeeTier: EntryFeeTier,
  playerCount: number,
): Promise<CreatedRoom> {
  const requestUrl = `${normalizeBaseUrl(runtimeConfig.roomsBaseUrl)}/v0/rooms`;
  let response: Response;
  try {
    response = await fetch(requestUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        creator_display_name: creatorDisplayName.trim(),
        entry_fee_tier: entryFeeTier,
        player_count: playerCount,
      }),
    });
  } catch {
    const origin = new URL(requestUrl).origin;
    throw new Error(
      `Could not reach the room service at ${origin}.`,
    );
  }

  const responseBody = (await response.json().catch(() => ({}))) as
    | CreateRoomResponse
    | { error?: string; details?: unknown };

  if (!response.ok) {
    throw new Error(
      `Room creation failed (${response.status}): ${JSON.stringify(responseBody)}`,
    );
  }

  const createdRoom = responseBody as CreateRoomResponse;

  return {
    gameId: createdRoom.game_id,
    createdBy: createdRoom.created_by,
    entryFeeTier: createdRoom.entry_fee_tier,
    entryFeeAmount: createdRoom.entry_fee_amount,
    playerCount: createdRoom.player_count,
    createdAt: createdRoom.created_at,
  };
}

export async function getRoom(
  runtimeConfig: RuntimeConfig,
  gameId: string,
): Promise<PublicRoom> {
  const requestUrl = `${normalizeBaseUrl(runtimeConfig.roomsBaseUrl)}/v0/rooms/${gameId}`;
  let response: Response;
  try {
    response = await fetch(requestUrl);
  } catch {
    const origin = new URL(requestUrl).origin;
    throw new Error(`Could not reach the room service at ${origin}.`);
  }

  const responseBody = (await response.json().catch(() => ({}))) as
    | PublicRoomResponse
    | { error?: string; details?: unknown };

  if (!response.ok) {
    if (response.status === 404) {
      throw new Error("Room not found.");
    }

    throw new Error(
      `Room lookup failed (${response.status}): ${JSON.stringify(responseBody)}`,
    );
  }

  const room = responseBody as PublicRoomResponse;

  return {
    gameId: room.game_id,
    creatorDisplayName: room.creator_display_name,
    entryFeeTier: room.entry_fee_tier,
    entryFeeAmount: room.entry_fee_amount,
    playerCount: room.player_count,
    createdAt: room.created_at,
  };
}
