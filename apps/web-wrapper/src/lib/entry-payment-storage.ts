import type { VerifiedPayment } from "./payment";

type StoredEntryPayment = {
  txHash: string;
  verifiedPayment: VerifiedPayment | null;
};

function getStorageKey(gameId: string, playerAddress: string): string {
  return `evanopolis_wrapper_entry_payment:${gameId}:${playerAddress.toLowerCase()}`;
}

export function loadStoredEntryPayment(
  gameId: string,
  playerAddress: string,
): StoredEntryPayment | null {
  const rawValue = window.localStorage.getItem(getStorageKey(gameId, playerAddress));
  if (rawValue === null) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as StoredEntryPayment;
  } catch {
    return null;
  }
}

export function saveStoredEntryPayment(
  gameId: string,
  playerAddress: string,
  value: StoredEntryPayment,
): void {
  window.localStorage.setItem(
    getStorageKey(gameId, playerAddress),
    JSON.stringify(value),
  );
}

export function clearStoredEntryPayment(
  gameId: string,
  playerAddress: string,
): void {
  window.localStorage.removeItem(getStorageKey(gameId, playerAddress));
}
