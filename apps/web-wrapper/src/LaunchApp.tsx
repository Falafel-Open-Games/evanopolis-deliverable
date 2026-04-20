import { useEffect, useMemo, useRef, useState } from "react";

import { clearLaunchPayload, loadLaunchPayload } from "./lib/launch";
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

export function LaunchApp() {
  const launchPayload = useMemo(() => loadLaunchPayload(), []);
  const runtimeConfig = useMemo(() => getRuntimeConfig(), []);
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

  return (
    <main className="launch-shell">
      {launchPayload === null ? (
        <section className="launch-fallback">
          <div className="status-block">
            <p>The game session is not available anymore.</p>
            <p>Return to the wrapper and launch the match again.</p>
          </div>
          <div className="button-row">
            <button type="button" onClick={handleReturnHome}>
              Return Home
            </button>
          </div>
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
