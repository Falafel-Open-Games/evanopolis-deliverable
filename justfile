default:
  @just --list

# Placeholder command map for the monorepo.
# Replace these with real commands as the source apps are migrated in.

install:
  @echo "TODO: install dependencies per app"

test:
  @echo "TODO: run game-server tests and public auth integration checks"

dev-auth:
  @echo "TODO: run the private ../tabletop-auth repo locally and point this repo at it"

dev-game:
  @echo "TODO: run apps/game-server locally"

stack-up:
  @echo "TODO: boot the integrated local stack with a sibling ../tabletop-auth checkout"
