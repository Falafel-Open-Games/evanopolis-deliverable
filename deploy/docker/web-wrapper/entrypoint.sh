#!/bin/sh
set -eu

runtime_config_path="/usr/share/nginx/html/runtime-config.js"

js_escape() {
  printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cat > "${runtime_config_path}" <<EOF
window.__EVANOPOLIS_CONFIG__ = {
  authBaseUrl: "$(js_escape "${AUTH_BASE_URL:-}")",
  roomsBaseUrl: "$(js_escape "${ROOMS_BASE_URL:-}")",
  expectedChainId: "$(js_escape "${EXPECTED_CHAIN_ID:-}")",
  gameServerUrl: "$(js_escape "${GAME_SERVER_URL:-}")",
  paymentTokenAddress: "$(js_escape "${PAYMENT_TOKEN_ADDRESS:-}")",
  paymentHandlerAddress: "$(js_escape "${PAYMENT_HANDLER_ADDRESS:-}")",
  paymentAdapterAddress: "$(js_escape "${PAYMENT_ADAPTER_ADDRESS:-}")"
};
EOF
