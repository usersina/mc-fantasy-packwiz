#!/usr/bin/env bash
set -euo pipefail

MOD_ID="butchery-blood-grate-fix"
MOD_VERSION="1.0.0"
MC_VERSION="1.21.1"
LOADER="neoforge"

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$MOD_DIR/../.." && pwd)"
RUNTIME_DIR="${MINECRAFT_RUNTIME_DIR:-$REPO_DIR/dist/inspect/server-generated/runtime}"
JAVA_BIN="${JAVA21:-/usr/lib/jvm/java-21-openjdk/bin/java}"
JAVAC_BIN="${JAVAC:-$(dirname "$JAVA_BIN")/javac}"
JAR_BIN="${JAR:-$(dirname "$JAVA_BIN")/jar}"
BUILD_DIR="$MOD_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAR_NAME="${MOD_ID}-${MOD_VERSION}+mc${MC_VERSION}-${LOADER}.jar"
OUTPUT_JAR="$REPO_DIR/mods/$JAR_NAME"

if [ ! -x "$JAVAC_BIN" ]; then
  echo "ERROR: javac not found at $JAVAC_BIN"
  exit 1
fi

if [ ! -x "$JAR_BIN" ]; then
  echo "ERROR: jar not found at $JAR_BIN"
  exit 1
fi

if [ ! -d "$RUNTIME_DIR/libraries" ] || [ ! -d "$RUNTIME_DIR/mods" ]; then
  cat <<EOF
ERROR: missing materialized server runtime at:
  $RUNTIME_DIR

Run this first:
  go-task pack:inspect INSPECT=server-generated
EOF
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"

patched_server_jar="$(find "$RUNTIME_DIR/libraries/net/neoforged/neoforge" -type f -name 'neoforge-*-server.jar' | sort | tail -n 1)"
if [ -z "$patched_server_jar" ]; then
  echo "ERROR: NeoForge patched server jar not found under $RUNTIME_DIR/libraries"
  exit 1
fi

classpath="$patched_server_jar:$(
  {
    find "$RUNTIME_DIR/libraries" -type f -name '*.jar'
    find "$RUNTIME_DIR/mods" -type f -name '*.jar'
  } | sort | paste -sd ':' -
)"

find "$MOD_DIR/src/main/java" -type f -name '*.java' > "$BUILD_DIR/sources.txt"

"$JAVAC_BIN" --release 21 -proc:none -cp "$classpath" -d "$CLASSES_DIR" @"$BUILD_DIR/sources.txt"
cp -R "$MOD_DIR/src/main/resources/." "$CLASSES_DIR/"

mkdir -p "$(dirname "$OUTPUT_JAR")"
rm -f "$OUTPUT_JAR"
(
  cd "$CLASSES_DIR"
  mapfile -t jar_files < <(find . -type f | sort | sed 's#^\./##')
  "$JAR_BIN" --create --file "$OUTPUT_JAR" --date=2024-01-01T00:00:00+00:00 "${jar_files[@]}"
)

echo "==> Built $OUTPUT_JAR"
