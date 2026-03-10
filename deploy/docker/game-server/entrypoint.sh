#!/usr/bin/env sh
set -eu

port="${GAME_SERVER_PORT:-9010}"

set -- godot --headless --path /app --scene res://scenes/server_main.tscn -- --port "${port}" "$@"

exec "$@"
