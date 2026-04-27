# Graphical Client Screen Specs

This document describes the minimum responsibilities of in-game graphical
client screens before Godot UI implementation begins.

Unlike the wrapper docs, these screens start after launch handoff and session
admission.

## 1. Waiting Room / Title Screen

Goal:
- give the player a clear first in-game landing screen after session connect
- present the game identity in a more player-facing way than a generic status
  panel
- give the player a short orientation about the game goal and pre-match flow
- let the player see who is present in the room
- give the player one lightweight pre-match customization affordance while
  waiting
- let the player manually mark ready

Primary actions:
- ready up
- optionally adjust short-name / icon / color identity inputs

Inputs:
- connected launch payload context
- authoritative sync snapshot
- `rpc_player_joined(...)`
- `rpc_player_ready_state(...)`
- `rpc_game_started(...)`

Must communicate:
- this is now the actual game client, not the wrapper anymore
- the player successfully entered a real match session
- what kind of game the player is about to enter
- only the minimum room facts needed for orientation
- who is ready and who is still waiting
- what the local player can do next

Visual direction:
- should function as the first lightweight title screen for the game
- expressive and game-like rather than debug-like
- strong title treatment for `EVANOPOLIS`
- can lean playful or slightly cartoony if that gives the game more character
- avoid looking like a web dashboard, admin table, or generic web3 product page
- avoid oversized technical or transport-summary panels

Core layout blocks:
- title area
- game orientation card
- roster / seat list
- small local identity area
- primary local action area
- small live status line

Minimum data the screen should show:
- game name
- short subtitle or one-line framing
- short explanation of the game goal or match dynamics
- room or match identifier
- connected player count versus intended room size
- local player identity
- editable short player name if supported
- selected icon from a fixed 10-icon set if supported
- selected color from a fixed 6-color set if supported
- roster of joined players
- ready state per player

Example orientation copy:
- "In this game you are a bitcoin mining entrepreneur who has to make purchase
  decisions about strategic properties in different cities to build your mining
  operation and achieve maximum hash power against the other miners in the
  world."
- "You win if your opponents go broke, or if you accumulate 20 Bitcoins, or if
  you are the biggest miner after the length of the game."

States:
- initial waiting-room after sync
- local player not ready
- local player ready
- other players joining
- other players readying
- match starting
- server-side failure after sync but before start

Behavior notes:
- do not auto-ready the local player
- local ready action should become disabled or replaced once sent
- `rpc_game_started(...)` should leave this screen immediately into the next
  placeholder state
- if identity editing is present, keep it intentionally constrained:
  - short name text field
  - fixed icon picker with 16 choices
  - fixed color picker with 6 choices
- avoid open-ended avatar upload, free color picking, or profile systems

Non-goals for this screen:
- board rendering
- turn actions
- full reconnect UX beyond the current session gate
- creator-only early-start flow in the first version

## Deferred Visual Follow-Up

Later iterations may add:

- creator-only early-start button if the game-server contract grows to support
  it
- richer player cards with avatars, colors, or seat identity
- ambient background art or board hints
- animated transition into gameplay

For the first pass, clarity is more important than decorative complexity.

## API Direction Note

If we add short-name, icon, or color selection, that data should probably not
live in `rooms-api` as room metadata.

Reason:
- `rooms-api` currently describes the room itself
- short name / icon / color are per-player state
- more than one player in the same room will need distinct values

The cleaner likely direction is:
- a game-server or session RPC for ephemeral per-match player presentation
  state
- snapshot and broadcast support so the waiting room can show it authoritatively

`rooms-api` is still a reasonable place for creator-facing room metadata such as
the existing `creator_display_name`, but it is not the natural home for full
per-player lobby identity.

This should be tracked as a follow-up against the game-server RPC API and sync
snapshot design before the identity-editing UI is treated as complete.
