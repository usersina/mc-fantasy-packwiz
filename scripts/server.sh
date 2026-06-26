#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SERVER_BASE_DIR="${SERVER_BASE_DIR:-$REPO_DIR/server-base}"
SERVER_DIR="${SERVER_DIR:-/data/games/servers/minecraft/fantasy-lan}"
PACK_URL="${PACK_URL:-http://127.0.0.1:8080/pack.toml}"
JAVA21="${JAVA21:-/usr/lib/jvm/java-21-openjdk/bin/java}"
NEOFORGE_VERSION="${NEOFORGE_VERSION:-21.1.233}"
PACKWIZ_INSTALLER_VERSION="${PACKWIZ_INSTALLER_VERSION:-v0.0.3}"
PACKWIZ_INSTALLER_URL="${PACKWIZ_INSTALLER_URL:-https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/${PACKWIZ_INSTALLER_VERSION}/packwiz-installer-bootstrap.jar}"
FORCE="${FORCE:-false}"
ACCEPT_EULA="${ACCEPT_EULA:-false}"
BACKUP_DIR="${BACKUP_DIR:-/data/games/servers/minecraft/backups/fantasy-lan}"
ACTION="${1:-}"

BASE_FILES=(
  server.properties
  user_jvm_args.txt
)

NEOFORGE_INSTALLER="neoforge-${NEOFORGE_VERSION}-installer.jar"
NEOFORGE_URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/${NEOFORGE_INSTALLER}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <setup|update|start|diff-base|apply-base|backup>

Actions:
  setup       Create/install the server runtime.
  update      Sync Packwiz-managed mods/configs/global datapacks.
  start       Sync Packwiz-managed files, then start NeoForge.
  diff-base   Compare server-base templates against runtime copies.
  apply-base  Back up and overwrite runtime base files from server-base.
  backup      Back up the active world, server.properties, JVM args, and config/.
EOF
}

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

require_base_dir() {
  if [ ! -d "$SERVER_BASE_DIR" ]; then
    echo "ERROR: server-base template folder not found: $SERVER_BASE_DIR"
    exit 1
  fi
}

require_runtime_dir() {
  if [ ! -d "$SERVER_DIR" ]; then
    echo "ERROR: server runtime not found: $SERVER_DIR"
    echo "Run first:"
    echo "  task server:setup"
    exit 1
  fi
}

require_java21() {
  local first_line
  local major

  if [ ! -x "$JAVA21" ]; then
    echo "ERROR: Java 21 not found at: $JAVA21"
    echo "Run with JAVA21=/path/to/java21 or update Taskfile.yml."
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

copy_base_file() {
  local file="$1"
  local source="$SERVER_BASE_DIR/$file"
  local target="$SERVER_DIR/$file"

  if [ "$FORCE" = "true" ] || [ ! -f "$target" ]; then
    cp -p "$source" "$target"
    return 0
  fi

  return 1
}

setup_server() {
  local file
  local -a copied_base_files=()

  require_base_dir
  require_java21

  echo "==> Repo:   $REPO_DIR"
  echo "==> Base:   $SERVER_BASE_DIR"
  echo "==> Server: $SERVER_DIR"
  echo "==> NeoForge: $NEOFORGE_VERSION"

  mkdir -p "$SERVER_DIR"

  echo "==> Copying server base templates"
  for file in "${BASE_FILES[@]}"; do
    if copy_base_file "$file"; then
      copied_base_files+=("$file")
    fi
  done

  cd "$SERVER_DIR"

  echo "==> Downloading NeoForge installer if needed"
  download_if_missing "$NEOFORGE_INSTALLER" "$NEOFORGE_URL"

  echo "==> Installing NeoForge server if needed"
  if [ ! -f run.sh ]; then
    "$JAVA21" -jar "$NEOFORGE_INSTALLER" --installServer
  else
    echo "run.sh already exists; skipping NeoForge install"
  fi

  if [ "${#copied_base_files[@]}" -gt 0 ]; then
    echo "==> Re-applying copied server base templates"
    for file in "${copied_base_files[@]}"; do
      cp -p "$SERVER_BASE_DIR/$file" "$SERVER_DIR/$file"
    done
  fi

  echo "==> Downloading Packwiz installer if needed"
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
  fi

  echo
  echo "==> Done."
  echo "Next:"
  echo "  1. In terminal 1:"
  echo "     cd $REPO_DIR && task pack:serve"
  echo "  2. In terminal 2:"
  echo "     cd $REPO_DIR && task server:start"
}

find_neoforge_args() {
  local args="libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt"

  if [ ! -f "$args" ] && [ -d libraries/net/neoforged/neoforge ]; then
    args="$(find libraries/net/neoforged/neoforge -mindepth 2 -maxdepth 2 -name unix_args.txt -print | sort -V | tail -n 1)"
  fi

  if [ -z "$args" ] || [ ! -f "$args" ]; then
    echo "ERROR: NeoForge argfile not found in $SERVER_DIR" >&2
    echo "Run first:" >&2
    echo "  task server:setup" >&2
    exit 1
  fi

  printf "%s\n" "$args"
}

sync_packwiz() {
  require_runtime_dir
  require_java21

  cd "$SERVER_DIR"

  if [ ! -f packwiz-installer-bootstrap.jar ]; then
    echo "==> Downloading Packwiz installer"
    download_if_missing packwiz-installer-bootstrap.jar "$PACKWIZ_INSTALLER_URL"
  fi

  echo "==> Java version"
  "$JAVA21" -version

  echo "==> Syncing server-side Packwiz files"
  "$JAVA21" -jar packwiz-installer-bootstrap.jar -g -s server "$PACK_URL"
}

start_server() {
  local neoforge_args

  sync_packwiz
  neoforge_args="$(find_neoforge_args)"

  echo "==> Starting NeoForge server"
  echo "==> NeoForge args: $neoforge_args"
  "$JAVA21" @user_jvm_args.txt "@$neoforge_args" nogui
}

diff_base() {
  local file
  local runtime_file
  local template_file
  local different=false

  require_base_dir
  require_runtime_dir

  for file in "${BASE_FILES[@]}"; do
    template_file="$SERVER_BASE_DIR/$file"
    runtime_file="$SERVER_DIR/$file"

    if [ ! -f "$runtime_file" ]; then
      echo "==> Missing runtime file: $runtime_file"
      different=true
      continue
    fi

    if ! diff -u --label "server-base/$file" --label "$SERVER_DIR/$file" "$template_file" "$runtime_file"; then
      different=true
    fi
  done

  if [ "$different" = "true" ]; then
    echo "==> Differences found. Use 'task server:apply-base' only when you want repo templates to overwrite runtime copies."
  else
    echo "==> Runtime base files match server-base templates."
  fi
}

apply_base() {
  local file
  local runtime_file
  local template_file
  local backup_dir
  local stamp

  require_base_dir
  require_runtime_dir

  stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  backup_dir="$SERVER_DIR/base-template-backups/$stamp"
  mkdir -p "$backup_dir"

  echo "==> Backing up current runtime base files to:"
  echo "    $backup_dir"

  for file in "${BASE_FILES[@]}"; do
    runtime_file="$SERVER_DIR/$file"
    template_file="$SERVER_BASE_DIR/$file"

    if [ -f "$runtime_file" ]; then
      cp -p "$runtime_file" "$backup_dir/$file"
    fi

    cp -p "$template_file" "$runtime_file"
  done

  echo "==> Applied server-base templates to $SERVER_DIR"
}

backup_server() {
  local stamp
  local world_name
  local world_dir
  local backup_items

  require_runtime_dir

  stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  world_name="$(sed -n 's/^level-name=//p' "$SERVER_DIR/server.properties" 2>/dev/null | tail -n 1)"
  world_name="${world_name:-world}"
  world_dir="$SERVER_DIR/$world_name"
  backup_items=("$world_name" server.properties user_jvm_args.txt)

  mkdir -p "$BACKUP_DIR"

  if [ ! -d "$world_dir" ]; then
    echo "ERROR: world folder not found: $world_dir"
    exit 1
  fi

  if [ -d "$SERVER_DIR/config" ]; then
    backup_items+=(config)
  fi

  tar --zstd -cf "$BACKUP_DIR/${world_name}-$stamp.tar.zst" \
    -C "$SERVER_DIR" \
    "${backup_items[@]}"

  echo "Backup created:"
  echo "$BACKUP_DIR/${world_name}-$stamp.tar.zst"
}

case "$ACTION" in
  setup)
    setup_server
    ;;
  update)
    sync_packwiz
    ;;
  start)
    start_server
    ;;
  diff-base)
    diff_base
    ;;
  apply-base)
    apply_base
    ;;
  backup)
    backup_server
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage
    echo
    echo "ERROR: unknown action: $ACTION"
    exit 1
    ;;
esac
