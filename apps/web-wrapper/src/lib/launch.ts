import type { RuntimeConfig } from "./runtime-config";

const LAUNCH_PAYLOAD_STORAGE_KEY = "evanopolis_wrapper_launch_payload";

export type LaunchPayload = {
  token: string;
  gameId: string;
  gameServerUrl: string;
  playerAddress: string;
};

export function buildLaunchPayload(args: {
  runtimeConfig: RuntimeConfig;
  token: string;
  gameId: string;
  playerAddress: string;
}): LaunchPayload {
  return {
    token: args.token,
    gameId: args.gameId,
    gameServerUrl: args.runtimeConfig.gameServerUrl,
    playerAddress: args.playerAddress,
  };
}

export function saveLaunchPayload(payload: LaunchPayload): void {
  window.sessionStorage.setItem(
    LAUNCH_PAYLOAD_STORAGE_KEY,
    JSON.stringify(payload),
  );
}

export function loadLaunchPayload(): LaunchPayload | null {
  const rawValue = window.sessionStorage.getItem(LAUNCH_PAYLOAD_STORAGE_KEY);
  if (rawValue === null) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as LaunchPayload;
  } catch {
    return null;
  }
}

export function normalizeLaunchPayload(args: {
  payload: LaunchPayload | null;
  runtimeConfig: RuntimeConfig;
  requestedGameId: string | null;
}): LaunchPayload | null {
  const { payload, runtimeConfig, requestedGameId } = args;
  if (payload === null) {
    return null;
  }

  const normalizedGameId =
    requestedGameId !== null && requestedGameId.trim().length > 0
      ? requestedGameId.trim()
      : payload.gameId;
  const normalizedGameServerUrl = runtimeConfig.gameServerUrl.trim();

  if (normalizedGameId.length === 0 || normalizedGameServerUrl.length === 0) {
    return null;
  }

  return {
    ...payload,
    gameId: normalizedGameId,
    gameServerUrl: normalizedGameServerUrl,
  };
}

export function clearLaunchPayload(): void {
  window.sessionStorage.removeItem(LAUNCH_PAYLOAD_STORAGE_KEY);
}

export function buildLaunchUrl(payload: LaunchPayload): string {
  const launchUrl = new URL("/launch.html", window.location.origin);
  launchUrl.searchParams.set("game_id", payload.gameId);
  return launchUrl.toString();
}
