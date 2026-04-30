# Pawn API

The runtime pawn layer now has two pieces:

- `Pawn`: one table piece for one player.
- `PawnCollection`: the scene-level manager that creates, colors, and places pawns.

## `Pawn`

`res://scripts/game/pawns/pawn.gd`

Use this when you already know which pawn instance you want to update.

- `configure(player_index: int, color_id: int, transform: Transform3D) -> void`
- `set_player_index(player_index: int) -> void`
- `set_color_id(color_id: int) -> void`
- `set_board_position(position: Vector3, basis: Basis = Basis.IDENTITY) -> void`
- `set_board_transform(transform: Transform3D) -> void`

Behavior:

- `player_index` is the logical player owner.
- `color_id` uses the same identity color contract as the waiting room and HUD.
- position/transform are local to the `PawnCollection` scene.
- the pawn mesh is a single reusable template; runtime color comes from the canonical player identity palette, not from Blender material order.

## `PawnCollection`

`res://scripts/game/pawns/pawn_collection.gd`

Use this from `GameRoot` or later match-presentation code.

- `sync_waiting_room_slots(slots: Array) -> void`
- `ensure_pawn(player_index: int, initial_color_id: int = 0) -> Pawn`
- `set_pawn_color(player_index: int, color_id: int) -> void`
- `set_pawn_position(player_index: int, position: Vector3, basis: Basis = Basis.IDENTITY) -> void`
- `set_pawn_transform(player_index: int, transform: Transform3D) -> void`
- `get_default_spawn_transform(color_id: int) -> Transform3D`
- `remove_pawn(player_index: int) -> void`
- `clear_pawns() -> void`

Behavior:

- the imported `pawns.glb` scene is now treated as source data, not the public API
- one imported pawn mesh becomes the reusable geometry template
- the six imported transforms become default spawn slots keyed by `color_id`
- current game-scene handoff uses `sync_waiting_room_slots(...)` so known players appear automatically with the correct identity color

## Current Placement Rule

The current start-tile rule is:

- treat each of the six exported legacy pawn markers as the authoritative start-tile hint for that `color_id`
- snap that color to the nearest actual tile in the instantiated 18-tile ring

Implementation detail:

- tile order comes from the instantiated board geometry
- the pawn export therefore preserves the intended start tile for each color
- exported marker names are the stable keys, and gameplay `color_id` now comes directly from the numeric suffix (`..._000` -> `color_id 0`, ..., `..._005` -> `color_id 5`)
- `CentralAnchor` is used when it provides a real tile point; otherwise the mesh top center is used as a fallback

Current canonical `color_id` order:

- `0`: ice
- `1`: green
- `2`: sky
- `3`: red
- `4`: purple
- `5`: gold

That gives us a stable placeholder presentation now while keeping the next step
obvious:

- keep `player_index` and `color_id`
- replace the default spawn transform with authoritative board/tile transforms later
