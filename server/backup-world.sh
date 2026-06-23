#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/data/games/servers/minecraft/fantasy-lan}"
BACKUP_DIR="${BACKUP_DIR:-/data/games/servers/minecraft/backups/fantasy-lan}"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"

mkdir -p "$BACKUP_DIR"

if [ ! -d "$SERVER_DIR/world" ]; then
  echo "ERROR: world folder not found: $SERVER_DIR/world"
  exit 1
fi

tar --zstd -cf "$BACKUP_DIR/world-$STAMP.tar.zst" \
  -C "$SERVER_DIR" \
  world server.properties user_jvm_args.txt

echo "Backup created:"
echo "$BACKUP_DIR/world-$STAMP.tar.zst"
