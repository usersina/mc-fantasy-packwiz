#!/usr/bin/env bash
set -euo pipefail

MOD_ID="jer-compat-fix"
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
JER_META="$REPO_DIR/mods/just-enough-resources-jer.pw.toml"

toml_value() {
  local file="$1"
  local key="$2"
  awk -F'"' -v key="$key" '$1 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$file"
}

if [ ! -x "$JAVAC_BIN" ] || [ ! -x "$JAR_BIN" ]; then
  echo "ERROR: Java 21 compiler tools were not found beside $JAVA_BIN"
  exit 1
fi

for command in curl sha512sum; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command"
    exit 1
  fi
done

if [ ! -d "$RUNTIME_DIR/libraries" ] || [ ! -d "$RUNTIME_DIR/mods" ]; then
  cat <<EOF
ERROR: missing materialized server runtime at:
  $RUNTIME_DIR

Run this first:
  go-task pack:inspect INSPECT=server-generated
EOF
  exit 1
fi

if [ ! -f "$JER_META" ]; then
  echo "ERROR: JER Packwiz metadata is missing: $JER_META"
  exit 1
fi

jer_filename="$(toml_value "$JER_META" filename)"
jer_url="$(toml_value "$JER_META" url)"
jer_hash="$(toml_value "$JER_META" hash)"
if [ -z "$jer_filename" ] || [ -z "$jer_url" ] || [ -z "$jer_hash" ]; then
  echo "ERROR: could not resolve JER filename, URL, or hash from $JER_META"
  exit 1
fi

jer_jar="$REPO_DIR/.cache/$jer_filename"
mkdir -p "$(dirname "$jer_jar")"
if [ ! -f "$jer_jar" ] || ! printf '%s  %s\n' "$jer_hash" "$jer_jar" | sha512sum --check --status; then
  echo "==> Downloading JER build dependency"
  curl --fail --location --retry 3 --output "$jer_jar.tmp" "$jer_url"
  mv "$jer_jar.tmp" "$jer_jar"
fi

if ! printf '%s  %s\n' "$jer_hash" "$jer_jar" | sha512sum --check --status; then
  echo "ERROR: downloaded JER jar does not match Packwiz metadata"
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"

patched_server_jar="$(find "$RUNTIME_DIR/libraries/net/neoforged/neoforge" -type f -name 'neoforge-*-server.jar' | sort | tail -n 1)"
if [ -z "$patched_server_jar" ]; then
  echo "ERROR: NeoForge patched server jar not found under $RUNTIME_DIR/libraries"
  exit 1
fi

classpath="$jer_jar:$patched_server_jar:$({
  find "$RUNTIME_DIR/libraries" -type f -name '*.jar'
  find "$RUNTIME_DIR/mods" -type f -name '*.jar'
} | sort | paste -sd ':' -)"

find "$MOD_DIR/src/main/java" -type f -name '*.java' | sort > "$BUILD_DIR/sources.txt"
"$JAVAC_BIN" --release 21 -proc:none -cp "$classpath" -d "$CLASSES_DIR" @"$BUILD_DIR/sources.txt"
cp -R "$MOD_DIR/src/main/resources/." "$CLASSES_DIR/"

mkdir -p "$(dirname "$OUTPUT_JAR")"
rm -f "$REPO_DIR/mods/${MOD_ID}-"*"+mc${MC_VERSION}-${LOADER}.jar"
(
  cd "$CLASSES_DIR"
  mapfile -t jar_files < <(find . -type f | sort | sed 's#^\./##')
  "$JAR_BIN" --create --file "$OUTPUT_JAR" --date=2024-01-01T00:00:00+00:00 --no-manifest --no-compress "${jar_files[@]}"
)

echo "==> Built $OUTPUT_JAR"
