import { useMemo } from "react";

import { clearLaunchPayload, loadLaunchPayload } from "./lib/launch";

function buildLandingUrl(): string {
  return new URL("/", window.location.origin).toString();
}

function buildEmbedPlaceholderMarkup(args: {
  gameId: string;
  gameServerUrl: string;
  playerAddress: string;
}): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Evanopolis Client</title>
    <style>
      :root {
        color-scheme: dark;
        font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
        background: radial-gradient(circle at top, #243144 0, #121922 58%, #0a0f15 100%);
        color: #f4efe2;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        padding: 24px;
      }
      .card {
        width: min(760px, 100%);
        padding: 32px;
        border: 1px solid rgba(244, 239, 226, 0.18);
        background: rgba(10, 15, 21, 0.78);
      }
      .eyebrow {
        margin: 0 0 12px;
        font-size: 12px;
        letter-spacing: 0.16em;
        text-transform: uppercase;
        color: #d3c5a1;
      }
      h1 {
        margin: 0 0 12px;
        font-size: clamp(32px, 5vw, 54px);
        line-height: 0.94;
      }
      p {
        margin: 0 0 18px;
        color: #d6d2c9;
        line-height: 1.6;
      }
      .meta {
        display: grid;
        gap: 12px;
        margin-top: 20px;
      }
      .meta-row {
        padding: 14px 16px;
        background: rgba(244, 239, 226, 0.08);
        border: 1px solid rgba(244, 239, 226, 0.12);
      }
      .meta-label {
        display: block;
        margin-bottom: 6px;
        font-size: 12px;
        letter-spacing: 0.12em;
        text-transform: uppercase;
        color: #a8b5c4;
      }
      code {
        font-family: "IBM Plex Mono", monospace;
        overflow-wrap: anywhere;
      }
    </style>
  </head>
  <body>
    <main class="card">
      <p class="eyebrow">Evanopolis</p>
      <h1>Embedded Client Placeholder</h1>
      <p>
        This page is reserved for the migrated Godot web client. The wrapper
        has already completed payment verification and passed the launch state
        into this internal launch surface.
      </p>
      <div class="meta">
        <div class="meta-row">
          <span class="meta-label">Room</span>
          <code>${args.gameId}</code>
        </div>
        <div class="meta-row">
          <span class="meta-label">Server</span>
          <code>${args.gameServerUrl}</code>
        </div>
        <div class="meta-row">
          <span class="meta-label">Player</span>
          <code>${args.playerAddress}</code>
        </div>
      </div>
    </main>
  </body>
</html>`;
}

export function LaunchApp() {
  const launchPayload = useMemo(() => loadLaunchPayload(), []);

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
      ) : (
        <iframe
          title="Evanopolis Embedded Client"
          className="launch-frame"
          srcDoc={buildEmbedPlaceholderMarkup({
            gameId: launchPayload.gameId,
            gameServerUrl: launchPayload.gameServerUrl,
            playerAddress: launchPayload.playerAddress,
          })}
        />
      )}
    </main>
  );
}
