#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CLIENT_PACK_SLUG="${CLIENT_PACK_SLUG:-mc-fantasy}"
DIST_DIR="${DIST_DIR:-dist}"

cd "$REPO_DIR"

VERSION="$(awk -F'"' '/^version = / { print $2; exit }' pack.toml)"
MC_VERSION="$(awk -F'"' '/^minecraft = / { print $2; exit }' pack.toml)"

if [ -z "$VERSION" ] || [ -z "$MC_VERSION" ]; then
  echo "ERROR: could not read version or minecraft from pack.toml"
  exit 1
fi

packwiz refresh

OUT="${DIST_DIR%/}/${CLIENT_PACK_SLUG}-${MC_VERSION}-v${VERSION}.mrpack"
STABLE_OUT="${DIST_DIR%/}/${CLIENT_PACK_SLUG}-stable.mrpack"
mkdir -p "$DIST_DIR"
rm -f "$OUT" "$STABLE_OUT"
packwiz modrinth export -o "$OUT"
cp "$OUT" "$STABLE_OUT"

echo "==> Wrote $OUT"
echo "==> Wrote $STABLE_OUT"

if [ "${GITHUB_OUTPUT:-}" != "" ]; then
  {
    echo "pack_version=$VERSION"
    echo "minecraft_version=$MC_VERSION"
    echo "asset_name=$(basename "$OUT")"
    echo "asset_path=$OUT"
    echo "stable_asset_name=$(basename "$STABLE_OUT")"
    echo "stable_asset_path=$STABLE_OUT"
  } >> "$GITHUB_OUTPUT"
fi
