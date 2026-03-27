#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 https://<app-name>.fly.dev" >&2
  exit 1
fi

base_url="${1%/}"

curl --fail --silent --show-error "${base_url}/healthz" >/dev/null
curl --fail --silent --show-error "${base_url}/" >/dev/null
curl --fail --silent --show-error "${base_url}/invite.html" >/dev/null
curl --fail --silent --show-error "${base_url}/launch.html" >/dev/null

echo "web-wrapper fly smoke check passed for ${base_url}"
