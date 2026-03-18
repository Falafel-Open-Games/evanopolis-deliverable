# Game Server Migration Checklist

Source repo: `../evanopolis-ui-slice/godot2`

## Copy First

- `scenes/`
- `scripts/`
- `tests/`
- any project files required to run the Godot headless server

## Keep In The First Slice

- headless server runtime
- auth integration hooks
- match/rules tests
- reconnect and sync tests

## Defer

- text-only client as a product surface
- offline demo code
- UI-specific assets not needed by the server runtime

## Validation After Copy

- boot headless server locally
- run server tests
- verify auth-backed join flow still works
- verify at least one full match path after migration
