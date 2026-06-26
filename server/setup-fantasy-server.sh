#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SERVER_BASE_DIR="${SERVER_BASE_DIR:-$REPO_DIR/server/base}"
SERVER_DIR="${SERVER_DIR:-/data/games/servers/minecraft/fantasy-lan}"
NEOFORGE_VERSION="${NEOFORGE_VERSION:-21.1.233}"
JAVA21="${JAVA21:-/usr/lib/jvm/java-21-openjdk/bin/java}"
FORCE="${FORCE:-false}"
ACCEPT_EULA="${ACCEPT_EULA:-false}"

NEOFORGE_INSTALLER="neoforge-${NEOFORGE_VERSION}-installer.jar"
NEOFORGE_URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/${NEOFORGE_INSTALLER}"
PACKWIZ_INSTALLER_VERSION="${PACKWIZ_INSTALLER_VERSION:-v0.0.3}"
PACKWIZ_INSTALLER_URL="${PACKWIZ_INSTALLER_URL:-https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/${PACKWIZ_INSTALLER_VERSION}/packwiz-installer-bootstrap.jar}"

download_if_missing() {
  local output="$1"
  local url="$2"
  local tmp

  if [ -f "$output" ]; then
    return 0
  fi

  tmp="$(mktemp "${output}.tmp.XXXXXX")"
  if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "ERROR: failed to download $url"
    exit 1
  fi
  mv "$tmp" "$output"
}

echo "==> Repo:   $REPO_DIR"
echo "==> Base:   $SERVER_BASE_DIR"
echo "==> Server: $SERVER_DIR"
echo "==> NeoForge: $NEOFORGE_VERSION"

if [ ! -d "$SERVER_BASE_DIR" ]; then
  echo "ERROR: server base template folder not found: $SERVER_BASE_DIR"
  exit 1
fi

if [ ! -x "$JAVA21" ]; then
  echo "ERROR: Java 21 not found at: $JAVA21"
  echo "On Arch/Garuda, try:"
  echo "  sudo pacman -S jdk21-openjdk"
  echo "Or run with:"
  echo "  JAVA21=/path/to/java21 ./server/setup-fantasy-server.sh"
  exit 1
fi

JAVA_VERSION_FIRST_LINE="$("$JAVA21" -version 2>&1 | sed -n '1p')"
JAVA_MAJOR="$(printf "%s\n" "$JAVA_VERSION_FIRST_LINE" | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')"
if [ "$JAVA_MAJOR" != "21" ]; then
  echo "ERROR: JAVA21 must point to Java 21, but got:"
  echo "  $JAVA_VERSION_FIRST_LINE"
  exit 1
fi

echo "==> Java: $JAVA_VERSION_FIRST_LINE"

mkdir -p "$SERVER_DIR"

echo "==> Copying server base templates"
if [ "$FORCE" = "true" ]; then
  rsync -av "$SERVER_BASE_DIR/" "$SERVER_DIR/"
else
  rsync -av --ignore-existing "$SERVER_BASE_DIR/" "$SERVER_DIR/"
  rsync -av "$SERVER_BASE_DIR/start-packwiz-server.sh" "$SERVER_DIR/start-packwiz-server.sh"
fi

cd "$SERVER_DIR"

echo "==> Downloading NeoForge installer if needed"
download_if_missing "$NEOFORGE_INSTALLER" "$NEOFORGE_URL"

echo "==> Installing NeoForge server if needed"
if [ ! -f "run.sh" ]; then
  "$JAVA21" -jar "$NEOFORGE_INSTALLER" --installServer
else
  echo "run.sh already exists; skipping NeoForge install"
fi

echo "==> Downloading packwiz installer if needed"
download_if_missing packwiz-installer-bootstrap.jar "$PACKWIZ_INSTALLER_URL"

echo "==> Handling EULA"
if [ "$ACCEPT_EULA" = "true" ]; then
  printf "eula=true\n" > eula.txt
  echo "EULA accepted via ACCEPT_EULA=true"
else
  if [ ! -f eula.txt ]; then
    printf "eula=false\n" > eula.txt
  fi
  echo "EULA not auto-accepted. Edit:"
  echo "  $SERVER_DIR/eula.txt"
  echo "or rerun:"
  echo "  ACCEPT_EULA=true ./server/setup-fantasy-server.sh"
fi

chmod +x "$SERVER_DIR/start-packwiz-server.sh"

echo
echo "==> Done."
echo "Next:"
echo "  1. In terminal 1:"
echo "     cd $REPO_DIR && task pack:serve"
echo "  2. In terminal 2:"
echo "     cd $REPO_DIR && task server:start"
