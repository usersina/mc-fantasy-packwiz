#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PACK_URL="${PACK_URL:-https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml}"
JAVA21="${JAVA21:-/usr/lib/jvm/java-21-openjdk/bin/java}"
PACKWIZ_INSTALLER_VERSION="${PACKWIZ_INSTALLER_VERSION:-v0.0.3}"
PACKWIZ_INSTALLER_URL="${PACKWIZ_INSTALLER_URL:-https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/${PACKWIZ_INSTALLER_VERSION}/packwiz-installer-bootstrap.jar}"
PACKWIZ_INSTALLER_CACHE="${PACKWIZ_INSTALLER_CACHE:-$REPO_DIR/.cache/packwiz-installer-bootstrap-${PACKWIZ_INSTALLER_VERSION}.jar}"
KEEP_SMOKE_DIR="${KEEP_SMOKE_DIR:-false}"
created_smoke_dir=false

if [ "${SMOKE_DIR:-}" = "" ]; then
  SMOKE_DIR="$(mktemp -d)"
  created_smoke_dir=true
else
  mkdir -p "$SMOKE_DIR"
fi

cleanup() {
  local status="$1"

  if [ "$status" -eq 0 ] && [ "$created_smoke_dir" = "true" ] && [ "$KEEP_SMOKE_DIR" != "true" ]; then
    rm -rf "$SMOKE_DIR"
    return 0
  fi

  echo "==> Smoke client folder retained:"
  echo "    $SMOKE_DIR"
}
trap 'status=$?; cleanup "$status"' EXIT

download_if_missing() {
  local output="$1"
  local url="$2"
  local tmp

  if [ -f "$output" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$output")"
  tmp="$(mktemp "${output}.tmp.XXXXXX")"
  if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "ERROR: failed to download $url"
    exit 1
  fi
  mv "$tmp" "$output"
}

require_java21() {
  local first_line
  local major

  if [ ! -x "$JAVA21" ]; then
    echo "ERROR: Java 21 not found at: $JAVA21"
    exit 1
  fi

  first_line="$("$JAVA21" -version 2>&1 | sed -n '1p')"
  major="$(printf "%s\n" "$first_line" | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')"
  if [ "$major" != "21" ]; then
    echo "ERROR: JAVA21 must point to Java 21, but got:"
    echo "  $first_line"
    exit 1
  fi
}

require_path() {
  local path="$1"

  if [ ! -e "$SMOKE_DIR/$path" ]; then
    echo "ERROR: smoke update did not create expected path: $path"
    exit 1
  fi
}

require_mod_match() {
  local label="$1"
  local pattern="$2"

  if ! find "$SMOKE_DIR/mods" -type f -iname "$pattern" -print -quit | grep -q .; then
    echo "ERROR: smoke update did not install expected mod jar: $label ($pattern)"
    exit 1
  fi
}

require_java21
download_if_missing "$PACKWIZ_INSTALLER_CACHE" "$PACKWIZ_INSTALLER_URL"

echo "==> Smoke client folder:"
echo "    $SMOKE_DIR"
echo "==> Pack URL:"
echo "    $PACK_URL"

(
  cd "$SMOKE_DIR"
  "$JAVA21" -jar "$PACKWIZ_INSTALLER_CACHE" -g -s client "$PACK_URL"
)

require_path "mods"
require_path "defaultconfigs/waystones-common.toml"
require_path "config/paxi/datapacks/minecraft_convenience_recipes/pack.mcmeta"
require_mod_match "Configured" "configured-*.jar"
require_mod_match "More Dragon Eggs" "moredragoneggs-*.jar"

mod_count="$(find "$SMOKE_DIR/mods" -type f -name '*.jar' | wc -l)"

echo "==> Client updater smoke test passed"
echo "==> Installed $mod_count mod jars"
