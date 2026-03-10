default:
  @just --list

# Placeholder command map for the monorepo.
# Replace these with real commands as the source apps are migrated in.

install:
  @echo "TODO: install dependencies per app"

test:
  cd apps/game-server && godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit

dev-auth:
  @echo "TODO: run the private ../tabletop-auth repo locally and point this repo at it"

dev-game:
  cd apps/game-server && godot --headless --path . --scene res://scenes/server_main.tscn

stack-up:
  @echo "TODO: boot the integrated local stack with a sibling ../tabletop-auth checkout"
