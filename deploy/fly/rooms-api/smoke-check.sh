#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <http-or-https-base-url>" >&2
    exit 1
fi

base_url="${1%/}"

curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "${base_url}/healthz"
