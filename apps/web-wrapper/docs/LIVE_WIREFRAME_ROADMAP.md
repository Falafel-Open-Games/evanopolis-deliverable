# Live Wireframe Roadmap

This roadmap captures the immediate pivot for `apps/web-wrapper/`:
ship a minimal live browser flow for real invitation testing before committing
to a final visual system.

## Actionables

1. Create a minimal `Vite + React + TypeScript` wrapper runtime.
   Use the smallest framework stack that keeps auth, room, and invite state
   readable without introducing a full design-system or frontend architecture
   commitment.

2. Keep the visual language intentionally neutral.
   Use a restrained grayscale layout with clear hierarchy, borders, spacing,
   and readable forms. Treat this as a live wireframe, not the final design
   system.

3. Keep the component structure explicit and shallow.
   Organize the first pass around a few obvious screens or panels for runtime
   config, auth, room creation, invite lookup, and launch handoff. Avoid UI
   kits, complex routing, and hidden state layers.

4. Make runtime configuration visible and editable in the UI.
   Expose the auth base URL, rooms API base URL, expected chain, and optional
   launch endpoints so staging and local testing do not require code edits for
   every environment change.

5. Implement real wallet auth against `tabletop-auth`.
   Support connect wallet, chain enforcement, challenge request, SIWE signing,
   verify, and in-memory JWT handling with clear error states.

6. Implement real room creation against `rooms-api`.
   Allow authenticated users to create a room with the current stable
   `player_count` contract and receive a real `game_id`.

7. Implement invitation generation and acceptance.
   Generate a shareable invite URL carrying `game_id`, support manual invite
   URL or room-code entry, and validate rooms through `GET /v0/rooms/:game_id`.

8. Add a launch-handoff placeholder without hardening the final contract yet.
   Show the launch payload and optional target URL shape needed for the future
   graphical client handoff, but keep this layer explicitly provisional.

9. Add lightweight automated coverage for pure helper logic.
   Cover invite parsing, URL generation, and runtime-config normalization so the
   wrapper does not rely only on manual browser checks.

10. Update the app documentation around one obvious run path.
   Document how to run the wrapper locally, how to test the live flow, and what
   remains intentionally provisional.

11. Remove the abandoned prompt-first design artifacts.
    Delete the old `design/prompts` and `design/stitch_wireframes_*` material so
    the app folder reflects the implementation-first direction.

12. Validate the full browser path manually.
    Confirm wallet auth, room creation, invite copy/open, room lookup, and the
    launch placeholder behavior against real configured services.
