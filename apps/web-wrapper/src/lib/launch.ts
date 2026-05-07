import type { RuntimeConfig } from "./runtime-config";

const LAUNCH_PAYLOAD_STORAGE_KEY = "evanopolis_wrapper_launch_payload";
const LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY =
  "evanopolis_wrapper_launch_payload_fallback";
const LAUNCH_PAYLOAD_FALLBACK_MAX_AGE_MS = 30 * 60 * 1000;

export type LaunchPayload = {
  token: string;
  gameId: string;
  gameServerUrl: string;
  playerAddress: string;
};

type StoredLaunchPayloadFallback = {
  payload: LaunchPayload;
  savedAt: number;
};

function buildLaunchPayloadScopedStorageKey(launchId: string): string {
  return `${LAUNCH_PAYLOAD_STORAGE_KEY}:${launchId}`;
}

function normalizeLaunchId(launchId: string | null | undefined): string | null {
  if (typeof launchId !== "string") {
    return null;
  }

  const normalizedLaunchId = launchId.trim();
  return normalizedLaunchId.length > 0 ? normalizedLaunchId : null;
}

export function createLaunchId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  return `launch-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

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

export function saveLaunchPayload(
  payload: LaunchPayload,
  launchId?: string | null,
): void {
  const normalizedLaunchId = normalizeLaunchId(launchId);
  const serializedPayload = JSON.stringify(payload);

  window.sessionStorage.setItem(LAUNCH_PAYLOAD_STORAGE_KEY, serializedPayload);
  if (normalizedLaunchId !== null) {
    window.sessionStorage.setItem(
      buildLaunchPayloadScopedStorageKey(normalizedLaunchId),
      serializedPayload,
    );
  }
  window.localStorage.setItem(
    LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY,
    JSON.stringify({
      payload,
      savedAt: Date.now(),
    } satisfies StoredLaunchPayloadFallback),
  );
}

export function loadLaunchPayload(
  launchId?: string | null,
): LaunchPayload | null {
  const normalizedLaunchId = normalizeLaunchId(launchId);
  const rawValue =
    normalizedLaunchId !== null
      ? window.sessionStorage.getItem(
          buildLaunchPayloadScopedStorageKey(normalizedLaunchId),
        ) ?? window.sessionStorage.getItem(LAUNCH_PAYLOAD_STORAGE_KEY)
      : window.sessionStorage.getItem(LAUNCH_PAYLOAD_STORAGE_KEY);
  if (rawValue !== null) {
    try {
      return JSON.parse(rawValue) as LaunchPayload;
    } catch {
      if (normalizedLaunchId !== null) {
        window.sessionStorage.removeItem(
          buildLaunchPayloadScopedStorageKey(normalizedLaunchId),
        );
      }
      window.sessionStorage.removeItem(LAUNCH_PAYLOAD_STORAGE_KEY);
    }
  }

  try {
    const fallbackRawValue = window.localStorage.getItem(
      LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY,
    );
    if (fallbackRawValue === null) {
      return null;
    }

    const storedFallback = JSON.parse(
      fallbackRawValue,
    ) as StoredLaunchPayloadFallback;
    if (
      typeof storedFallback.savedAt !== "number" ||
      !Number.isFinite(storedFallback.savedAt) ||
      Date.now() - storedFallback.savedAt > LAUNCH_PAYLOAD_FALLBACK_MAX_AGE_MS
    ) {
      window.localStorage.removeItem(LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY);
      return null;
    }

    const payload = storedFallback.payload;
    if (
      typeof payload?.token !== "string" ||
      typeof payload?.gameId !== "string" ||
      typeof payload?.gameServerUrl !== "string" ||
      typeof payload?.playerAddress !== "string"
    ) {
      window.localStorage.removeItem(LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY);
      return null;
    }

    window.sessionStorage.setItem(
      LAUNCH_PAYLOAD_STORAGE_KEY,
      JSON.stringify(payload),
    );
    if (normalizedLaunchId !== null) {
      window.sessionStorage.setItem(
        buildLaunchPayloadScopedStorageKey(normalizedLaunchId),
        JSON.stringify(payload),
      );
    }
    return payload;
  } catch {
    window.localStorage.removeItem(LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY);
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

export function clearLaunchPayload(launchId?: string | null): void {
  const normalizedLaunchId = normalizeLaunchId(launchId);
  if (normalizedLaunchId !== null) {
    window.sessionStorage.removeItem(
      buildLaunchPayloadScopedStorageKey(normalizedLaunchId),
    );
  }
  window.sessionStorage.removeItem(LAUNCH_PAYLOAD_STORAGE_KEY);
  window.localStorage.removeItem(LAUNCH_PAYLOAD_FALLBACK_STORAGE_KEY);
}

export function buildLaunchUrl(
  payload: LaunchPayload,
  launchId?: string | null,
): string {
  const launchUrl = new URL("/launch.html", window.location.origin);
  launchUrl.searchParams.set("game_id", payload.gameId);
  const normalizedLaunchId = normalizeLaunchId(launchId);
  if (normalizedLaunchId !== null) {
    launchUrl.searchParams.set("launch_id", normalizedLaunchId);
  }
  return launchUrl.toString();
}
