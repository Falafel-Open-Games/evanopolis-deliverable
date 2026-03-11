#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <http-or-https-url>" >&2
    exit 1
fi

url="$1"
headers_file="$(mktemp)"
stderr_file="$(mktemp)"
trap 'rm -f "$headers_file" "$stderr_file"' EXIT

curl_exit=0

curl \
    --http1.1 \
    --max-time 5 \
    --silent \
    --show-error \
    --output /dev/null \
    --dump-header "$headers_file" \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
    "$url" 2>"$stderr_file" || curl_exit="$?"

status_line="$(sed -n '1p' "$headers_file" | tr -d '\r')"

if printf '%s\n' "$status_line" | grep -q "101 Switching Protocols"; then
    echo "websocket upgrade ok: $status_line"
    exit 0
fi

if [ "$curl_exit" -ne 0 ]; then
    echo "websocket check request failed with curl exit $curl_exit" >&2
    sed -n '1,20p' "$stderr_file" >&2
fi

if ! printf '%s\n' "$status_line" | grep -q "^HTTP/"; then
    echo "websocket upgrade failed: $status_line" >&2
    sed -n '1,20p' "$headers_file" >&2
    exit 1
fi

echo "websocket upgrade failed: $status_line" >&2
sed -n '1,20p' "$headers_file" >&2
exit 1
