#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SITE_DIR="${SITE_DIR:-$REPO_DIR/dist/site/stable}"
SITE_INDEX_SOURCE="${SITE_INDEX_SOURCE:-$REPO_DIR/site/index.html}"

cd "$REPO_DIR"

case "$SITE_DIR" in
  ""|"."|"./"|"/"|"$REPO_DIR"|"$REPO_DIR/")
    echo "ERROR: refusing unsafe SITE_DIR: $SITE_DIR"
    exit 1
    ;;
esac

SITE_ROOT="$(dirname "$SITE_DIR")"
case "$SITE_ROOT" in
  ""|"."|"./"|"/"|"$REPO_DIR"|"$REPO_DIR/")
    echo "ERROR: refusing unsafe SITE_ROOT from SITE_DIR: $SITE_DIR"
    exit 1
    ;;
esac

if [ ! -f pack.toml ] || [ ! -f index.toml ]; then
  echo "ERROR: pack.toml and index.toml must exist in $REPO_DIR"
  exit 1
fi

if [ ! -f "$SITE_INDEX_SOURCE" ]; then
  echo "ERROR: site index source is missing: $SITE_INDEX_SOURCE"
  exit 1
fi

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR" "$SITE_ROOT"

cp -p "$SITE_INDEX_SOURCE" "$SITE_ROOT/index.html"
cp -p pack.toml index.toml "$SITE_DIR/"

count=0
while IFS= read -r file; do
  if [ -z "$file" ]; then
    continue
  fi

  case "$file" in
    /*|*../*|../*)
      echo "ERROR: unsafe index path: $file"
      exit 1
      ;;
  esac

  if [ ! -f "$file" ]; then
    echo "ERROR: indexed file is missing: $file"
    exit 1
  fi

  mkdir -p "$SITE_DIR/$(dirname "$file")"
  cp -p "$file" "$SITE_DIR/$file"
  count=$((count + 1))
done < <(awk -F'"' '/^[[:space:]]*file[[:space:]]*=/ { print $2 }' index.toml)

echo "==> Built Packwiz site:"
echo "    $SITE_DIR"
echo "==> Copied root index:"
echo "    $SITE_ROOT/index.html"
echo "==> Copied $count indexed files plus pack.toml and index.toml"
