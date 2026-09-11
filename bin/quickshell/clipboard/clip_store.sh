#!/usr/bin/env bash
# Lucretia - Clipboard storage handler with separated quotas (50 images, 2000 text)
TARGET="${1:-text}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$TARGET" = "prune" ]; then
    exec "$DIR/clip_fetcher" prune
else
    exec "$DIR/clip_fetcher" store "$TARGET"
fi
