# Graphical Client Wireframes

These are low-fidelity in-game wireframes for discussion only.

They are here to define screen structure, information hierarchy, and likely UI
elements before we harden the Godot scenes.

The first in-game screen to specify is the waiting room because it is the first
player-facing surface where the user may actually pause and look around.

## Waiting Room / Title Screen

```text
+--------------------------------------------------------------------+
| EVANOPOLIS                                                         |
| Build the strongest Bitcoin mining operation on the board          |
|                                                                    |
| Waiting for match start                                            |
| Room 00f16095-c61a-469b-8b8e-5f5b7beab1ed                          |
| 2 / 4 players connected                                            |
| Entry: 0.10 TRT                                                    |
|                                                                    |
| Evanopolis at a glance                                              |
| +----------------------------------------------------------------------+
| | In this game you are a bitcoin mining entrepreneur who has to make |
| | purchase decisions about strategic properties in different cities  |
| | to build your mining operation and achieve maximum hash power      |
| | against the other miners in the world.                             |
| |                                                                    |
| | You win if your opponents go broke, or if you accumulate 20        |
| | Bitcoins, or if you are the biggest miner after the length of the  |
| | game.                                                              |
| +----------------------------------------------------------------------+
|                                                                    |
| Your identity                                                       |
| +----------------------------------------------------------------------+
| | Short name: [ SatoshiFox____ ]                                     |
| | Icon: fixed picker (10 choices)                                    |
| | Color: fixed picker (6 choices)                                    |
| +----------------------------------------------------------------------+
|                                                                    |
| Players in room                                                     |
| +----------------------------------------------------------------------+
| | Slot | Player                         | State                      |
| |------|--------------------------------|----------------------------|
| | 1    | 0x2075...2985                  | Ready                      |
| | 2    | 0x4f4f...ea58                  | Waiting                    |
| | 3    | Empty                          | Open                       |
| | 4    | Empty                          | Open                       |
| +----------------------------------------------------------------------+
|                                                                    |
| [ Ready ]                                                          |
|                                                                    |
| Small status line:                                                  |
| Waiting for more players or ready confirmations from the server.    |
+--------------------------------------------------------------------+
```

## Notes

- The game name and tagline should be visible immediately.
- This should feel like the first real title screen, not a debug lobby.
- Room facts should stay light; the larger content area should orient the
  player around the game rather than repeat transport/debug data.
- The player list should be easy to scan at a glance.
- The primary local action should be obvious.
- Empty slots should still be visible so room size is legible.
- A small pre-start identity area is acceptable if it gives the player
  something useful to do while waiting, but it should stay lightweight.
- Keep it constrained: fixed icon and color choices are better than open-ended
  customization for the first version.
- Error or reconnect messaging can live in the bottom status line without
  taking over the entire screen.

## AI Mockup Brief

Use this prompt as a starting point for visual mockups in tools such as
ChatGPT image generation or Stitch-like layout tools:

```text
Design a waiting-room screen for a game called EVANOPOLIS.

This is the first in-game title screen, not a generic lobby. It should feel
playful, stylized, and memorable rather than like a generic crypto dashboard or
web3 landing page template. It should still read clearly as a strategy game
screen, but it does not need to look corporate, metallic, or "premium fintech."

Layout requirements:
- large game title at the top
- short subtitle about building the strongest Bitcoin mining operation
- prominent waiting-room heading
- a game-oriented information card explaining the goal and pre-match context
- small identity customization area for short name, fixed icon choices, and
  fixed color choices
- player roster card with 2 to 4 slots and clear ready/waiting/open states
- a strong primary "Ready" button
- small footer status line for live session text

Visual direction:
- dark, atmospheric background
- expressive and game-like rather than corporate
- slightly cartoony or illustrated is acceptable
- sharp typography with clear hierarchy
- readable enough for a real game UI, not just a poster
- avoid crypto-bro branding clichés, token-dashboard widgets, exchange-app
  panels, or generic web3 hero-section aesthetics

Do not show gameplay board elements yet. This screen is only the pre-match
waiting room.
```
