import { useEffect, useMemo, useState } from "react";

import { JoinGamePanel } from "./components/JoinGamePanel";
import { SignInPanel } from "./components/SignInPanel";
import { useWalletSession } from "./hooks/useWalletSession";
import { deriveInviteRoomId, getInviteReferrerAddress } from "./lib/invite";
import { formatEntryFeeLabel, getRoom, type PublicRoom } from "./lib/rooms";
import { getRuntimeConfig } from "./lib/runtime-config";

type RoomLookupState = "idle" | "loading" | "ready" | "error";

function getInitialRoomCode(): string {
  const currentUrl = new URL(window.location.href);
  const gameId = currentUrl.searchParams.get("game_id");
  return gameId?.trim() ?? "";
}

function buildLandingUrl(): string {
  return new URL("/", window.location.origin).toString();
}

export function InviteApp() {
  const [recoveryInput, setRecoveryInput] = useState<string>("");
  const [roomDetails, setRoomDetails] = useState<PublicRoom | null>(null);
  const [roomLookupState, setRoomLookupState] = useState<RoomLookupState>("idle");
  const [roomLookupStatus, setRoomLookupStatus] = useState<string>("");
  const roomIdFromUrl = getInitialRoomCode();
  const inviteReferrerAddress = getInviteReferrerAddress();
  const recoveryRoomId = useMemo(
    () => deriveInviteRoomId(recoveryInput),
    [recoveryInput],
  );
  const activeRoomId =
    roomIdFromUrl.length > 0 ? roomIdFromUrl : recoveryRoomId;
  const isInviteFirstLanding = roomIdFromUrl.length > 0;
  const runtimeConfig = useMemo(() => getRuntimeConfig(), []);
  const {
    authSession,
    authStatusMessage,
    isConnectingWallet,
    handleConnectWallet,
  } = useWalletSession(runtimeConfig);

  function handleBackToLanding() {
    window.location.assign(buildLandingUrl());
  }

  useEffect(() => {
    if (activeRoomId.length === 0) {
      setRoomDetails(null);
      setRoomLookupState("idle");
      setRoomLookupStatus("");
      return;
    }

    let cancelled = false;
    setRoomLookupState("loading");
    setRoomLookupStatus("Loading room...");

    void getRoom(runtimeConfig, activeRoomId)
      .then((room) => {
        if (cancelled) {
          return;
        }

        setRoomDetails(room);
        setRoomLookupState("ready");
        setRoomLookupStatus("Room ready.");
      })
      .catch((error) => {
        if (cancelled) {
          return;
        }

        setRoomDetails(null);
        setRoomLookupState("error");
        setRoomLookupStatus(
          error instanceof Error ? error.message : "Could not load room.",
        );
      });

    return () => {
      cancelled = true;
    };
  }, [activeRoomId, runtimeConfig]);

  return (
    <div className="app-shell invite-shell">
      <header className="hero">
        <p className="eyebrow">Evanopolis</p>
        <h1>
          {isInviteFirstLanding
            ? roomLookupState === "error"
              ? "This invite could not be found."
              : roomDetails !== null
              ? `${roomDetails.creatorDisplayName} invited you to a match.`
              : "You have been invited to a live match."
            : "Recover a room and continue to join."}
        </h1>
        <p className="hero-copy">
          {isInviteFirstLanding
            ? roomLookupState === "error"
              ? "The room may have expired or the invite link may be invalid. Check the link or ask the host for a new invite."
              : roomDetails !== null
              ? `Join ${roomDetails.creatorDisplayName}'s room, complete the entry payment, and continue into the match.`
              : "This page is the invite destination. Confirm the room below and continue through the join flow."
            : "Use this page as a fallback when the invite context was lost and you only have a room code."}
        </p>
      </header>

      <main className="grid invite-grid">
        <SignInPanel
          authSession={authSession}
          authStatusMessage={authStatusMessage}
          isConnectingWallet={isConnectingWallet}
          onConnectWallet={() => void handleConnectWallet()}
        />

        <section className="panel panel-wide">
          <div className="panel-heading">
            <h2>Join Room</h2>
            <span>
              {isInviteFirstLanding
                ? "Invite-first entry flow"
                : "Manual recovery flow"}
            </span>
          </div>
          {isInviteFirstLanding ? (
            <>
              <p className="inline-note">
                {roomLookupState === "loading"
                  ? "Loading invite..."
                  : roomLookupStatus || "Waiting for room lookup."}
              </p>
            </>
          ) : (
            <>
              <label>
                <span>Room Code</span>
                <input
                  value={recoveryInput}
                  placeholder="550e8400-e29b-41d4-a716-446655440000"
                  onChange={(event) => setRecoveryInput(event.target.value)}
                />
              </label>
              <div className="result-block">
                <p>Room to join</p>
                <code>{activeRoomId || "Enter a room code to continue"}</code>
              </div>
              {activeRoomId.length > 0 ? (
                <div className="result-block">
                  <p>Status</p>
                  <code>{roomLookupStatus || "Waiting for room lookup."}</code>
                </div>
              ) : null}
            </>
          )}
          {roomLookupState === "error" ? (
            <div className="button-row">
              <button type="button" onClick={handleBackToLanding}>
                Back
              </button>
            </div>
          ) : roomDetails === null ? (
            <p className="inline-note">
              Finish room lookup before continuing into payment and launch.
            </p>
          ) : (
            <JoinGamePanel
              authSession={authSession}
              title="Join Game"
              description="This invite is ready. Complete the entry payment and continue into the match when you are ready to join."
              runtimeConfig={runtimeConfig}
              gameId={activeRoomId}
              entryFeeAmount={roomDetails.entryFeeAmount}
              entryFeeLabel={formatEntryFeeLabel(roomDetails.entryFeeTier)}
              playerCount={roomDetails.playerCount}
              creatorDisplayName={roomDetails.creatorDisplayName}
              referrerAddress={inviteReferrerAddress}
            />
          )}
        </section>
      </main>
    </div>
  );
}
