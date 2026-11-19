#!/bin/bash
set -e

IMAGE="${1:?Usage: $0 <image:tag>}"
UPSTREAM_FILE="/etc/nginx/conf.d/blue-green-upstream.conf"
BACKUP_FILE="/etc/nginx/conf.d/blue-green-upstream.conf.bak"

ACTIVE_PORT=$(grep -oE '127\.0\.0\.1:[0-9]+' "$UPSTREAM_FILE" | head -n1 | cut -d: -f2)

case "$ACTIVE_PORT" in
    8080) TARGET_ENV=green; TARGET_PORT=8081 ;;
    8081) TARGET_ENV=blue;  TARGET_PORT=8080 ;;
    *)    echo "Could not detect active environment"; exit 1 ;;
esac

TARGET_URL="http://127.0.0.1:${TARGET_PORT}/"

sudo docker pull "$IMAGE"
echo "Replacing $TARGET_ENV container with $IMAGE..."
sudo docker rm -f "$TARGET_ENV" 2>/dev/null || true
sudo docker run -d --name "$TARGET_ENV" --restart unless-stopped \
    -p "${TARGET_PORT}:80" "$IMAGE"
sleep 3

echo "Checking health of $TARGET_ENV..."
if ! bash health_check.sh "$TARGET_URL"; then
    echo "Deployment aborted: target is unhealthy."
    exit 1
fi

echo "Backing up current Nginx configuration..."
sudo cp "$UPSTREAM_FILE" "$BACKUP_FILE"

echo "Switching traffic to $TARGET_ENV..."
echo "upstream blue_green_backend {
    server 127.0.0.1:$TARGET_PORT;
}" | sudo tee "$UPSTREAM_FILE" >/dev/null

if sudo nginx -t; then
    echo "Nginx configuration is valid. Reloading..."
    sudo systemctl reload nginx
    echo "Verifying application through Nginx..."

    if ! bash health_check.sh "http://127.0.0.1/"; then
        echo "Post-deployment verification failed!"
        echo "Restoring previous Nginx configuration..."
        sudo cp "$BACKUP_FILE" "$UPSTREAM_FILE"
        sudo nginx -t && sudo systemctl reload nginx
        echo "Previous traffic configuration restored."
        exit 1
    fi

    echo "Post-deployment verification passed."
    echo "Traffic switch to $TARGET_ENV completed."
else
    echo "Nginx validation failed. Restoring previous configuration..."
    sudo cp "$BACKUP_FILE" "$UPSTREAM_FILE"
    sudo nginx -t
    echo "Previous configuration restored. Nginx was not reloaded."
    exit 1
fi
