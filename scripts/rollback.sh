#!/bin/bash
set -e
cd "$(dirname "$0")"

UPSTREAM_FILE="/etc/nginx/conf.d/blue-green-upstream.conf"
ACTIVE_PORT=$(grep -oE '127\.0\.0\.1:[0-9]+' "$UPSTREAM_FILE" | head -n1 | cut -d: -f2)

case "$ACTIVE_PORT" in
    8080) PREV=green; PREV_PORT=8081 ;;
    8081) PREV=blue;  PREV_PORT=8080 ;;
    *)    echo "Could not detect active environment"; exit 1 ;;
esac

if ! bash health_check.sh "http://127.0.0.1:${PREV_PORT}/"; then
    echo "Rollback aborted: $PREV is unhealthy"
    exit 1
fi

echo "upstream blue_green_backend {
    server 127.0.0.1:$PREV_PORT;
}" | sudo tee "$UPSTREAM_FILE" >/dev/null

sudo nginx -t
sudo systemctl reload nginx
sleep 1
bash health_check.sh "http://127.0.0.1/"
echo "Rolled back to $PREV"
