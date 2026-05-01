import { useEffect, useMemo, useRef, useState } from "react";

import { signInWithWallet } from "./lib/auth";
import {
  buildLaunchPayload,
  clearLaunchPayload,
  loadLaunchPayload,
  saveLaunchPayload,
} from "./lib/launch";
import {
  buildLaunchPayloadMessage,
  parseOpenGameHostMessage,
} from "./lib/open-game-host";
import { getRuntimeConfig } from "./lib/runtime-config";

function buildLandingUrl(): string {
  return new URL("/", window.location.origin).toString();
}

function buildGraphicalClientUrl(configuredUrl: string): string {
  return new URL(configuredUrl, window.location.origin).toString();
}

function loadRequestedGameId(): string | null {
  const gameId = new URL(window.location.href).searchParams.get("game_id");
  if (gameId === null) {
    return null;
  }

  const normalizedGameId = gameId.trim();
  return normalizedGameId.length > 0 ? normalizedGameId : null;
}

export function LaunchApp() {
  const runtimeConfig = useMemo(() => getRuntimeConfig(), []);
  const requestedGameId = useMemo(() => loadRequestedGameId(), []);
  const [launchPayload, setLaunchPayload] = useState(() => loadLaunchPayload());
  const graphicalClientUrl = useMemo(() => {
    const configuredUrl = runtimeConfig.graphicalClientUrl.trim();
    if (configuredUrl.length === 0) {
      return null;
    }
    return buildGraphicalClientUrl(configuredUrl);
  }, [runtimeConfig]);
  const graphicalClientOrigin = useMemo(
    () => (graphicalClientUrl === null ? null : new URL(graphicalClientUrl).origin),
    [graphicalClientUrl],
  );
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const [isBridgeBound, setIsBridgeBound] = useState(false);
  const [isRecoveringLaunch, setIsRecoveringLaunch] = useState(false);
  const [recoveryMessage, setRecoveryMessage] = useState<string | null>(null);

  useEffect(() => {
    setIsBridgeBound(true);

    function handleMessage(event: MessageEvent) {
      const currentFrame = iframeRef.current;
      if (currentFrame === null) {
        return;
      }

      if (event.source !== currentFrame.contentWindow) {
        return;
      }

      if (graphicalClientOrigin === null || event.origin !== graphicalClientOrigin) {
        return;
      }

      const message = parseOpenGameHostMessage(event.data);
      if (message === null) {
        return;
      }

      if (message.type !== "client_ready") {
        return;
      }

      if (launchPayload === null) {
        return;
      }

      currentFrame.contentWindow?.postMessage(
        buildLaunchPayloadMessage(launchPayload),
        graphicalClientOrigin,
      );
    }

    window.addEventListener("message", handleMessage);

    return () => {
      window.removeEventListener("message", handleMessage);
    };
  }, [graphicalClientOrigin, launchPayload]);

  function handleReturnHome() {
    clearLaunchPayload();
    window.location.assign(buildLandingUrl());
  }

  async function handleReconnectWallet() {
    if (requestedGameId === null) {
      return;
    }

    setIsRecoveringLaunch(true);
    setRecoveryMessage("Reconnecting wallet and rebuilding launch session...");

    try {
      const session = await signInWithWallet(runtimeConfig);
      const recoveredLaunchPayload = buildLaunchPayload({
        runtimeConfig,
        token: session.token,
        gameId: requestedGameId,
        playerAddress: session.address,
      });
      saveLaunchPayload(recoveredLaunchPayload);
      setLaunchPayload(recoveredLaunchPayload);
      setRecoveryMessage(null);
    } catch (error) {
      setRecoveryMessage(
        error instanceof Error
          ? error.message
          : "Could not rebuild the launch session.",
      );
    } finally {
      setIsRecoveringLaunch(false);
    }
  }

  return (
    <main className="launch-shell">
      {launchPayload === null ? (
        <section className="launch-fallback">
          <div className="status-block">
            {requestedGameId === null ? (
              <>
                <p>The game session is not available anymore.</p>
                <p>Return to the wrapper and launch the match again.</p>
              </>
            ) : (
              <>
                <p>The saved launch session for this room is missing.</p>
                <p>
                  Reconnect the wallet to rebuild launch access for room{" "}
                  <code>{requestedGameId}</code>.
                </p>
              </>
            )}
          </div>
          <div className="button-row">
            {requestedGameId !== null ? (
              <button
                type="button"
                onClick={() => void handleReconnectWallet()}
                disabled={isRecoveringLaunch}
              >
                {isRecoveringLaunch ? "Reconnecting..." : "Reconnect Wallet"}
              </button>
            ) : null}
            <button type="button" onClick={handleReturnHome}>
              Return Home
            </button>
          </div>
          {recoveryMessage !== null ? (
            <p className="inline-note">{recoveryMessage}</p>
          ) : null}
        </section>
      ) : graphicalClientUrl === null ? (
        <section className="launch-fallback">
          <div className="status-block">
            <p>The graphical client URL is not configured yet.</p>
            <p>
              Set <code>VITE_GRAPHICAL_CLIENT_URL</code> for local dev or{" "}
              <code>GRAPHICAL_CLIENT_URL</code> for the container runtime, then
              launch the match again.
            </p>
          </div>
          <div className="button-row">
            <button type="button" onClick={handleReturnHome}>
              Return Home
            </button>
          </div>
        </section>
      ) : isBridgeBound ? (
        <iframe
          ref={iframeRef}
          title="Open Game Embedded Client"
          className="launch-frame"
          src={graphicalClientUrl}
        />
      ) : (
        <section className="launch-frame-empty">
          <div className="status-block">
            <p>Preparing launch bridge...</p>
            <p>The wrapper is binding the parent and iframe message channel.</p>
          </div>
        </section>
      )}
    </main>
  );
}
