default:
  @just --list

install:
  cd apps/rooms-api && npm ci
  cd apps/web-wrapper && npm ci

test:
  cd apps/rooms-api && npm test
  cd apps/game-server && godot --headless --path . --log-file /tmp/evanopolis-game-server-gut.log -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit

dev *args='':
  #!/usr/bin/env bash
  set -euo pipefail

  auth_base_url="${AUTH_BASE_URL:-http://127.0.0.1:3000}"
  rooms_api_base_url="${ROOMS_API_BASE_URL:-http://127.0.0.1:3001}"
  rooms_api_lookup_template="${ROOMS_API_LOOKUP_TEMPLATE:-/v0/rooms/%s}"
  game_server_port="${GAME_SERVER_PORT:-9010}"
  game_server_docker_image="${GAME_SERVER_DOCKER_IMAGE:-ghcr.io/falafel-open-games/evanopolis-game-server:latest}"
  web_wrapper_port="${WEB_WRAPPER_PORT:-5173}"
  use_docker=false
  use_static_wrapper=false
  declare -a pids=()
  declare -a dev_args=({{args}})

  for arg in "${dev_args[@]}"; do
    case "$arg" in
      --docker)
        use_docker=true
        ;;
      --static-wrapper)
        use_static_wrapper=true
        ;;
      *)
        printf 'Unknown argument for `just dev`: %s\n' "$arg" >&2
        printf 'Usage: just dev [--docker] [--static-wrapper]\n' >&2
        exit 2
        ;;
    esac
  done

  ensure_node_app_deps() {
    local app_path="$1"
    local bin_name="$2"

    if [ -x "$app_path/node_modules/.bin/$bin_name" ]; then
      return
    fi

    if ! command -v npm >/dev/null 2>&1; then
      printf 'Missing dependency: install `npm` to run %s.\n' "$app_path" >&2
      exit 127
    fi

    printf 'Installing %s dependencies with npm ci...\n' "$app_path"
    (
      cd "$app_path"
      npm ci
    )
  }

  require_command() {
    local bin_name="$1"
    local install_hint="$2"

    if command -v "$bin_name" >/dev/null 2>&1; then
      return
    fi

    printf 'Missing dependency: install `%s` to %s.\n' "$bin_name" "$install_hint" >&2
    exit 127
  }

  build_static_web_wrapper() {
    local dist_runtime_config_path="apps/web-wrapper/dist/runtime-config.js"

    printf 'Building static web-wrapper bundle...\n'
    (
      cd apps/web-wrapper
      AUTH_BASE_URL="$auth_base_url" \
      ROOMS_API_BASE_URL="$rooms_api_base_url" \
      ROOMS_BASE_URL="$rooms_api_base_url" \
      npm run build
    )

    printf '%s\n' \
      'window.__EVANOPOLIS_CONFIG__ = {' \
      '  authBaseUrl: window.location.origin,' \
      '  roomsBaseUrl: window.location.origin,' \
      '  gameServerUrl: window.location.origin.replace(/^http/, "ws"),' \
      '};' \
      > "$dist_runtime_config_path"
  }

  require_auth_health() {
    local health_url="${auth_base_url%/}/health"

    if ! command -v curl >/dev/null 2>&1; then
      printf 'Skipping auth health check because `curl` is not installed.\n'
      return
    fi

    if ! curl --fail --silent --show-error "$health_url" >/dev/null; then
      printf 'Auth service is not reachable at %s.\n' "$auth_base_url" >&2
      printf 'Start ../tabletop-auth first, usually with `just dev`, then retry.\n' >&2
      exit 1
    fi
  }

  cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM

    if [ "${#pids[@]}" -gt 0 ]; then
      printf '\nStopping local services...\n'
      kill "${pids[@]}" 2>/dev/null || true
      wait "${pids[@]}" 2>/dev/null || true
    fi

    exit "$exit_code"
  }

  trap cleanup EXIT INT TERM

  if [ "$use_docker" = true ]; then
    if ! command -v docker >/dev/null 2>&1; then
      printf 'Missing dependency: install `docker` to run apps/game-server with `just dev --docker`.\n' >&2
      exit 127
    fi

    game_server_runner=docker

    printf 'Refreshing evanopolis-game-server Docker image from %s because `--docker` was requested.\n' "$game_server_docker_image"
    docker pull "$game_server_docker_image"
    docker image rm -f evanopolis-game-server >/dev/null 2>&1 || true
    docker tag "$game_server_docker_image" evanopolis-game-server
  elif command -v godot >/dev/null 2>&1; then
    printf 'Preparing apps/game-server with a headless Godot import...\n'
    (
      cd apps/game-server
      just import
    )
    game_server_runner=local
  else
    printf 'Missing dependency: install `godot` to run apps/game-server locally.\n' >&2
    printf 'If you want the container path explicitly, run `just dev --docker`.\n' >&2
    exit 127
  fi

  ensure_node_app_deps apps/rooms-api tsx
  ensure_node_app_deps apps/web-wrapper vite
  if [ "$use_static_wrapper" = true ]; then
    require_command python3 "serve the static web-wrapper bundle"
  fi
  require_auth_health

  local_rooms_data_file="${ROOMS_DATA_FILE:-$HOME/.evanopolis/rooms.json}"

  printf 'Starting rooms-api on http://127.0.0.1:3001\n'
  printf 'Persisting local rooms to %s\n' "$local_rooms_data_file"
  (
    cd apps/rooms-api
    exec env \
      AUTH_BASE_URL="$auth_base_url" \
      ROOMS_DATA_FILE="$local_rooms_data_file" \
      npm run dev
  ) &
  pids+=("$!")

  printf 'Starting game-server on ws://127.0.0.1:%s\n' "$game_server_port"
  if [ "$game_server_runner" = "local" ]; then
    (
      cd apps/game-server
      exec env \
        AUTH_BASE_URL="$auth_base_url" \
        ROOMS_API_BASE_URL="$rooms_api_base_url" \
        GAME_SERVER_PORT="$game_server_port" \
        godot --headless --path . --log-file /tmp/evanopolis-game-server-dev.log --scene res://scenes/server_main.tscn -- --port "$game_server_port"
    ) &
  else
    (
      cd apps/game-server
      exec env \
        AUTH_BASE_URL="$auth_base_url" \
        AUTH_VERIFY_PATH="${AUTH_VERIFY_PATH:-}" \
        ROOMS_API_BASE_URL="$rooms_api_base_url" \
        ROOMS_API_LOOKUP_TEMPLATE="$rooms_api_lookup_template" \
        GAME_SERVER_PORT="$game_server_port" \
        just docker-run
    ) &
  fi
  pids+=("$!")

  if [ "$use_static_wrapper" = true ]; then
    printf 'Starting static web-wrapper on http://127.0.0.1:%s\n' "$web_wrapper_port"
    build_static_web_wrapper
    (
      exec python3 scripts/serve_static_wrapper.py \
        --root apps/web-wrapper/dist \
        --port "$web_wrapper_port" \
        --auth-base-url "$auth_base_url" \
        --rooms-base-url "$rooms_api_base_url" \
        --game-server-url "ws://127.0.0.1:${game_server_port}"
    ) &
  else
    printf 'Starting web-wrapper on http://127.0.0.1:%s\n' "$web_wrapper_port"
    (
      cd apps/web-wrapper
      exec env \
        AUTH_BASE_URL="$auth_base_url" \
        ROOMS_API_BASE_URL="$rooms_api_base_url" \
        ROOMS_BASE_URL="$rooms_api_base_url" \
        npm run dev -- --host 127.0.0.1 --port "$web_wrapper_port"
    ) &
  fi
  pids+=("$!")

  printf '\nAuth must already be running at %s.\n' "$auth_base_url"
  printf 'Open http://127.0.0.1:%s/ when the web-wrapper is ready.\n' "$web_wrapper_port"
  if [ "$game_server_runner" = "docker" ]; then
    printf 'Game server is running from Docker because `--docker` was requested.\n'
  fi
  if [ "$use_static_wrapper" = true ]; then
    printf 'Web wrapper is running from a static production build because `--static-wrapper` was requested.\n'
  fi
  printf 'Press Ctrl-C to stop rooms-api, game-server, and web-wrapper together.\n\n'

  wait -n "${pids[@]}"

dev-auth:
  cd ../tabletop-auth && just dev

tunnel-auth:
  cd ../tabletop-auth && just tunnel

dev-game:
  cd apps/game-server && AUTH_BASE_URL="${AUTH_BASE_URL:-http://127.0.0.1:3000}" ROOMS_API_BASE_URL="${ROOMS_API_BASE_URL:-http://127.0.0.1:3001}" godot --headless --path . --log-file /tmp/evanopolis-game-server-dev.log --scene res://scenes/server_main.tscn

dev-rooms:
  cd apps/rooms-api && AUTH_BASE_URL="${AUTH_BASE_URL:-http://127.0.0.1:3000}" ROOMS_DATA_FILE="${ROOMS_DATA_FILE:-$HOME/.evanopolis/rooms.json}" npm run dev

dev-wrapper:
  cd apps/web-wrapper && npm run dev

stack-up:
  @echo "Recommended local path:"
  @echo "  Terminal 1 (in ../tabletop-auth): just dev"
  @echo "  Terminal 2: just dev"
  @echo ""
  @echo "Optional convenience from this repo: just dev-auth"
  @echo ""
  @echo "Then open http://localhost:5173/ and use docs/runbooks/local-stack.md."
