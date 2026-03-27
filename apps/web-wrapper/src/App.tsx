import { useMemo, useRef, useState } from "react";

import { JoinGamePanel } from "./components/JoinGamePanel";
import { SignInPanel } from "./components/SignInPanel";
import { useWalletSession } from "./hooks/useWalletSession";
import { buildInviteUrl, deriveInviteRoomId } from "./lib/invite";
import {
  createRoom,
  formatEntryFeeLabel,
  type CreatedRoom,
} from "./lib/rooms";
import { getRuntimeConfig } from "./lib/runtime-config";

type RoomDraft = {
  playerCount: string;
  creatorLabel: string;
  entryFeeTier: "cheap" | "average" | "deluxe";
};

const DISPLAY_NAME_MAX_LENGTH = 32;

const DEFAULT_ROOM_DRAFT: RoomDraft = {
  playerCount: "2",
  creatorLabel: "",
  entryFeeTier: "average",
};

export function App() {
  const [roomDraft, setRoomDraft] = useState<RoomDraft>(DEFAULT_ROOM_DRAFT);
  const [createdRoom, setCreatedRoom] = useState<CreatedRoom | null>(null);
  const [inviteInput, setInviteInput] = useState<string>("");
  const [roomStatusMessage, setRoomStatusMessage] = useState<string>(
    "Create a room to generate an invite.",
  );
  const [isCreatingRoom, setIsCreatingRoom] = useState<boolean>(false);
  const [copyStatusMessage, setCopyStatusMessage] = useState<string>("");
  const runtimeConfig = useMemo(() => getRuntimeConfig(), []);
  const {
    authSession,
    authStatusMessage,
    isConnectingWallet,
    handleConnectWallet,
  } = useWalletSession(runtimeConfig);
  const signInSectionRef = useRef<HTMLDivElement | null>(null);
  const createRoomSectionRef = useRef<HTMLElement | null>(null);
  const inviteInputRef = useRef<HTMLInputElement | null>(null);

  const inviteRoomId = useMemo(
    () => deriveInviteRoomId(inviteInput),
    [inviteInput],
  );
  const createdRoomId = createdRoom?.gameId ?? "";
  const inviteUrl = useMemo(
    () => buildInviteUrl(createdRoomId, createdRoom?.createdBy ?? ""),
    [createdRoom, createdRoomId],
  );
  const isSignedIn = authSession !== null;
  const hasDisplayName = roomDraft.creatorLabel.trim().length > 0;

  function updateRoomDraft<K extends keyof RoomDraft>(
    key: K,
    value: RoomDraft[K],
  ) {
    if (createdRoom !== null) {
      setCreatedRoom(null);
      setRoomStatusMessage("Create a room to generate an invite.");
      setCopyStatusMessage("");
    }

    setRoomDraft((currentDraft) => ({
      ...currentDraft,
      [key]:
        key === "creatorLabel"
          ? (String(value).slice(0, DISPLAY_NAME_MAX_LENGTH) as RoomDraft[K])
          : value,
    }));
  }

  function scrollToSection(section: "sign-in" | "create-room") {
    const target =
      section === "sign-in" ? signInSectionRef.current : createRoomSectionRef.current;
    target?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  async function handleCreateRoom() {
    if (authSession === null) {
      void handleConnectWallet();
      return;
    }

    setIsCreatingRoom(true);
    setRoomStatusMessage("Creating room...");

    try {
      const room = await createRoom(
        runtimeConfig,
        authSession.token,
        roomDraft.creatorLabel,
        roomDraft.entryFeeTier,
        Number(roomDraft.playerCount),
      );
      setCreatedRoom(room);
      setRoomStatusMessage(
        `Room created for ${room.playerCount} players at ${formatEntryFeeLabel(room.entryFeeTier)}.`,
      );
    } catch (error) {
      setCreatedRoom(null);
      setRoomStatusMessage(
        error instanceof Error ? error.message : "Room creation failed.",
      );
    } finally {
      setIsCreatingRoom(false);
    }
  }

  function handleInviteFieldClick() {
    inviteInputRef.current?.select();
  }

  function handleOpenInvite() {
    const trimmedInviteInput = inviteInput.trim();
    if (trimmedInviteInput.length === 0) {
      return;
    }

    try {
      window.location.assign(new URL(trimmedInviteInput).toString());
    } catch {
      window.location.assign(buildInviteUrl(inviteRoomId));
    }
  }

  async function handleCopyInviteUrl() {
    if (inviteUrl.length === 0) {
      return;
    }

    try {
      await navigator.clipboard.writeText(inviteUrl);
      setCopyStatusMessage("Invite link copied.");
      inviteInputRef.current?.select();
    } catch {
      setCopyStatusMessage("Could not copy the invite link.");
    }
  }

  return (
    <div className="app-shell">
      <header className="hero">
        <p className="eyebrow">Evanopolis</p>
        <h1>Build the strongest mining operation on the board.</h1>
        <p className="hero-copy">
          Evanopolis is a strategic online board game about property control,
          expansion, and mining power. Create a room to start a new match, or
          open an invite if another player already sent you in.
        </p>
        <div className="hero-actions">
          <button
            className="button-link"
            type="button"
            onClick={() => scrollToSection(isSignedIn ? "create-room" : "sign-in")}
          >
            Create Room
          </button>
          <a className="button-link button-link-secondary" href="#open-invite">
            Open Invite
          </a>
        </div>
      </header>

      <main className="grid">
        <div ref={signInSectionRef} className="panel-column panel-column-sign-in">
          <SignInPanel
            authSession={authSession}
            authStatusMessage={authStatusMessage}
            isConnectingWallet={isConnectingWallet}
            onConnectWallet={() => void handleConnectWallet()}
          />
        </div>

        <section
          ref={createRoomSectionRef}
          className="panel panel-column panel-column-create-room"
          id="create-room"
        >
          <div className="panel-heading">
            <h2>Create Room</h2>
            <span>Start a new private online match</span>
          </div>
          <div className="form-grid">
            <label>
              <span>Display Name</span>
              <input
                disabled={!isSignedIn}
                maxLength={DISPLAY_NAME_MAX_LENGTH}
                required
                value={roomDraft.creatorLabel}
                placeholder="How your name should appear on the invite"
                onChange={(event) =>
                  updateRoomDraft("creatorLabel", event.target.value)
                }
              />
            </label>
            <p className="field-note">
              This name will be shown on invitation messages later. Up to 32
              characters.
            </p>
            <label>
              <span>Entry Fee</span>
              <select
                disabled={!isSignedIn}
                value={roomDraft.entryFeeTier}
                onChange={(event) =>
                  updateRoomDraft(
                    "entryFeeTier",
                    event.target.value as RoomDraft["entryFeeTier"],
                  )
                }
              >
                <option value="cheap">Cheap · 0.10 TRT</option>
                <option value="average">Average · 0.50 TRT</option>
                <option value="deluxe">Deluxe · 1.00 TRT</option>
              </select>
            </label>
            <label>
              <span>Room Size</span>
              <select
                disabled={!isSignedIn}
                value={roomDraft.playerCount}
                onChange={(event) =>
                  updateRoomDraft("playerCount", event.target.value)
                }
              >
                <option value="2">2 players</option>
                <option value="3">3 players</option>
                <option value="4">4 players</option>
              </select>
            </label>
          </div>
          {!isSignedIn ? (
            <p className="inline-note">
              Please sign in first by connecting your wallet.
            </p>
          ) : !hasDisplayName ? (
            <p className="inline-note">Please enter a display name first.</p>
          ) : null}
          <div className="button-row">
            <button
              type="button"
              disabled={!isSignedIn || !hasDisplayName || isCreatingRoom}
              onClick={() => void handleCreateRoom()}
            >
              {isCreatingRoom ? "Creating..." : "Create Room"}
            </button>
          </div>
          {createdRoomId.length > 0 ? (
            <>
              <div className="success-banner">
                <p className="success-title">Room created successfully.</p>
                <p className="success-copy">
                  Your room is ready. Share the invite link and continue when
                  you want to join as player one.
                </p>
              </div>
              <div className="result-block">
                <p>Room ID</p>
                <code>{createdRoomId}</code>
              </div>
              <div className="result-block">
                <p>Status</p>
                <code>{roomStatusMessage}</code>
              </div>
              <div className="result-block">
                <p>Invite URL</p>
                <div className="copy-field">
                  <input
                    ref={inviteInputRef}
                    readOnly
                    value={inviteUrl}
                    onClick={handleInviteFieldClick}
                    onFocus={handleInviteFieldClick}
                  />
                  <button type="button" onClick={() => void handleCopyInviteUrl()}>
                    Copy
                  </button>
                </div>
                {copyStatusMessage.length > 0 ? (
                  <p className="field-note">{copyStatusMessage}</p>
                ) : null}
              </div>
            </>
          ) : null}
          {createdRoom !== null ? (
            <JoinGamePanel
              authSession={authSession}
              description="Share the invite with the other players. When you are ready to take player one in this match, join the room yourself. All players, including the host, must complete the entry payment before joining."
              runtimeConfig={runtimeConfig}
              gameId={createdRoom.gameId}
              entryFeeAmount={createdRoom.entryFeeAmount}
              entryFeeLabel={formatEntryFeeLabel(createdRoom.entryFeeTier)}
              playerCount={createdRoom.playerCount}
              creatorDisplayName={roomDraft.creatorLabel.trim()}
              referrerAddress={createdRoom.createdBy}
            />
          ) : null}
        </section>

        <section className="panel" id="open-invite">
          <div className="panel-heading">
            <h2>Open Invite</h2>
            <span>Paste a full invite link or enter a room code</span>
          </div>
          <label>
            <span>Invite URL or Room Code</span>
            <input
              disabled={!isSignedIn}
              value={inviteInput}
              placeholder="https://wrapper.example/?game_id=..."
              onChange={(event) => setInviteInput(event.target.value)}
            />
          </label>
          {!isSignedIn ? (
            <p className="inline-note">
              Please sign in first by connecting your wallet.
            </p>
          ) : null}
          <div className="result-block">
            <p>Room to open</p>
            <code>{inviteRoomId || "Paste an invite or room code to continue"}</code>
          </div>
          <div className="button-row">
            <button
              type="button"
              disabled={!isSignedIn || inviteRoomId.length === 0}
              onClick={handleOpenInvite}
            >
              Continue
            </button>
          </div>
        </section>
      </main>
    </div>
  );
}
