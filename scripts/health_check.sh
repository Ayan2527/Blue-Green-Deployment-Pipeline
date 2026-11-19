#!/bin/bash

TARGET_URL="$1"

if [ -z "$TARGET_URL" ]; then
    echo "Usage: $0 <URL>"
    exit 1
fi

if curl -fsS "$TARGET_URL" >/dev/null; then
    echo "Health check passed: $TARGET_URL"
    exit 0
else
    echo "Health check failed: $TARGET_URL"
    exit 1
fi
