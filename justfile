default:
  @just --list

install:
  cd apps/rooms-api && npm install
  cd apps/web-wrapper && npm install

test:
  cd apps/rooms-api && npm test
  cd apps/game-server && godot --headless --path . --log-file /tmp/evanopolis-game-server-gut.log -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit

dev-auth:
  cd ../tabletop-auth && just dev

tunnel-auth:
  cd ../tabletop-auth && just tunnel

dev-game:
  cd apps/game-server && AUTH_BASE_URL="${AUTH_BASE_URL:-http://127.0.0.1:3000}" ROOMS_API_BASE_URL="${ROOMS_API_BASE_URL:-http://127.0.0.1:3001}" godot --headless --path . --log-file /tmp/evanopolis-game-server-dev.log --scene res://scenes/server_main.tscn

dev-rooms:
  cd apps/rooms-api && AUTH_BASE_URL="${AUTH_BASE_URL:-http://127.0.0.1:3000}" npm run dev

dev-wrapper:
  cd apps/web-wrapper && npm run dev

stack-up:
  @echo "Run these in separate terminals:"
  @echo "  just dev-auth"
  @echo "  just tunnel-auth"
  @echo "  just dev-rooms"
  @echo "  just dev-game"
  @echo "  just dev-wrapper"
  @echo ""
  @echo "Then open http://localhost:5173/ and use docs/runbooks/local-stack.md."
