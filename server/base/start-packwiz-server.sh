#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACK_URL="${PACK_URL:-http://127.0.0.1:8080/pack.toml}"
JAVA21="${JAVA21:-/usr/lib/jvm/java-21-openjdk/bin/java}"
NEOFORGE_VERSION="${NEOFORGE_VERSION:-21.1.233}"
PACKWIZ_INSTALLER_URL="${PACKWIZ_INSTALLER_URL:-https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar}"
SYNC_ONLY="${SYNC_ONLY:-false}"

cd "$SERVER_DIR"

if [ ! -x "$JAVA21" ]; then
  echo "ERROR: Java 21 not found at: $JAVA21"
  echo "Install it or run with: JAVA21=/path/to/java21 ./start-packwiz-server.sh"
  exit 1
fi

NEOFORGE_ARGS="libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt"

if [ ! -f "$NEOFORGE_ARGS" ]; then
  NEOFORGE_ARGS=""
  if [ -d "libraries/net/neoforged/neoforge" ]; then
    NEOFORGE_ARGS="$(find libraries/net/neoforged/neoforge -mindepth 2 -maxdepth 2 -name unix_args.txt -print | sort -V | tail -n 1)"
  fi
fi

if [ -z "$NEOFORGE_ARGS" ] || [ ! -f "$NEOFORGE_ARGS" ]; then
  echo "ERROR: NeoForge argfile not found in $SERVER_DIR"
  echo "Run the repo setup script first:"
  echo "  task server:setup"
  exit 1
fi

if [ ! -f "packwiz-installer-bootstrap.jar" ]; then
  echo "==> Downloading packwiz installer"
  curl -L -o packwiz-installer-bootstrap.jar "$PACKWIZ_INSTALLER_URL"
fi

echo "==> Java version"
JAVA_VERSION="$("$JAVA21" -version 2>&1)"
printf "%s\n" "$JAVA_VERSION"
JAVA_VERSION_FIRST_LINE="$(printf "%s\n" "$JAVA_VERSION" | sed -n '1p')"
JAVA_MAJOR="$(printf "%s\n" "$JAVA_VERSION_FIRST_LINE" | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')"
if [ "$JAVA_MAJOR" != "21" ]; then
  echo "ERROR: JAVA21 must point to Java 21, but got:"
  echo "  $JAVA_VERSION_FIRST_LINE"
  exit 1
fi

echo "==> Syncing server-side packwiz files"
"$JAVA21" -jar packwiz-installer-bootstrap.jar -g -s server "$PACK_URL"

WORLD_NAME="$(sed -n 's/^level-name=//p' server.properties 2>/dev/null | tail -n 1)"
WORLD_NAME="${WORLD_NAME:-world}"
PACK_DATAPACKS_DIR="$SERVER_DIR/datapacks"
WORLD_DATAPACKS_DIR="$SERVER_DIR/$WORLD_NAME/datapacks"

if [ -d "$PACK_DATAPACKS_DIR" ] && [ -n "$(find "$PACK_DATAPACKS_DIR" -mindepth 1 ! -name .gitkeep -print -quit)" ]; then
  echo "==> Syncing datapacks into $WORLD_DATAPACKS_DIR"
  mkdir -p "$WORLD_DATAPACKS_DIR"
  rsync -a --delete --exclude .gitkeep "$PACK_DATAPACKS_DIR/" "$WORLD_DATAPACKS_DIR/"
else
  echo "==> No repo datapacks to sync"
fi

if [ "$SYNC_ONLY" = "true" ]; then
  echo "==> Sync complete; not starting server because SYNC_ONLY=true"
  exit 0
fi

echo "==> Starting NeoForge server"
echo "==> NeoForge args: $NEOFORGE_ARGS"
"$JAVA21" @user_jvm_args.txt "@$NEOFORGE_ARGS" nogui
