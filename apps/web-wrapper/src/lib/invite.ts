import { getAddress } from "ethers";

function normalizeReferrerAddress(referrerAddress: string): string | null {
  const trimmedReferrerAddress = referrerAddress.trim();
  if (trimmedReferrerAddress.length === 0) {
    return null;
  }

  try {
    return getAddress(trimmedReferrerAddress);
  } catch {
    return null;
  }
}

export function buildInviteUrl(
  roomId: string,
  referrerAddress: string = "",
): string {
  if (roomId.length === 0) {
    return "";
  }

  const inviteUrl = new URL("/invite.html", window.location.origin);
  inviteUrl.searchParams.set("game_id", roomId);
  const normalizedReferrerAddress = normalizeReferrerAddress(referrerAddress);
  if (normalizedReferrerAddress !== null) {
    inviteUrl.searchParams.set(
      "potential_referrer",
      normalizedReferrerAddress,
    );
  }
  return inviteUrl.toString();
}

export function deriveInviteRoomId(inviteInput: string): string {
  const trimmedInviteInput = inviteInput.trim();
  if (trimmedInviteInput.length === 0) {
    return "";
  }

  try {
    const parsedUrl = new URL(trimmedInviteInput);
    return parsedUrl.searchParams.get("game_id") ?? trimmedInviteInput;
  } catch {
    return trimmedInviteInput;
  }
}

export function getInviteReferrerAddress(): string | null {
  const currentUrl = new URL(window.location.href);
  const potentialReferrer =
    currentUrl.searchParams.get("potential_referrer") ?? "";
  return normalizeReferrerAddress(potentialReferrer);
}
