# Graphical Client

This folder is reserved for the final graphical client.

The current likely source is `../evanopolis-ui-slice/godot`, but client migration should happen only after the server stack is consolidated and deployable.

## Migration Direction

Use the approved offline-demo UI as the baseline.

The main engineering task here is to adapt that client to:

- connect to the multiplayer stack
- consume authoritative RPC events
- replace local/offline game-state logic with server-driven flow
