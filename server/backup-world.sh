#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/data/games/servers/minecraft/fantasy-lan}"
BACKUP_DIR="${BACKUP_DIR:-/data/games/servers/minecraft/backups/fantasy-lan}"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
WORLD_NAME="$(sed -n 's/^level-name=//p' "$SERVER_DIR/server.properties" 2>/dev/null | tail -n 1)"
WORLD_NAME="${WORLD_NAME:-world}"
WORLD_DIR="$SERVER_DIR/$WORLD_NAME"
BACKUP_ITEMS=("$WORLD_NAME" server.properties user_jvm_args.txt)

mkdir -p "$BACKUP_DIR"

if [ ! -d "$WORLD_DIR" ]; then
  echo "ERROR: world folder not found: $WORLD_DIR"
  exit 1
fi

if [ -d "$SERVER_DIR/config" ]; then
  BACKUP_ITEMS+=(config)
fi

tar --zstd -cf "$BACKUP_DIR/${WORLD_NAME}-$STAMP.tar.zst" \
  -C "$SERVER_DIR" \
  "${BACKUP_ITEMS[@]}"

echo "Backup created:"
echo "$BACKUP_DIR/${WORLD_NAME}-$STAMP.tar.zst"
