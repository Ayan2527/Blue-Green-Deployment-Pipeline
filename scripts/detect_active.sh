#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/nginx/conf.d/blue-green-upstream.conf"

ACTIVE_PORT=$(grep -vE '^\s*#' "$CONF" \
  | grep -oE '127\.0\.0\.1:[0-9]+' \
  | head -n1 \
  | cut -d: -f2 || true)

case "$ACTIVE_PORT" in
  8080) ACTIVE=blue;  TARGET=green; TARGET_PORT=8081 ;;
  8081) ACTIVE=green; TARGET=blue;  TARGET_PORT=8080 ;;
  *)
    echo "ERROR: could not detect active environment (got: '${ACTIVE_PORT}')" >&2
    exit 1
    ;;
esac

echo "Active environment : $ACTIVE (port $ACTIVE_PORT)"
echo "Deployment target  : $TARGET (port $TARGET_PORT)"
