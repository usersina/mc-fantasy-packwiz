#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SITE_DIR="${SITE_DIR:-$REPO_DIR/dist/site/stable}"
SITE_INDEX_SOURCE="${SITE_INDEX_SOURCE:-$REPO_DIR/site/index.html}"
CLIENT_PACK_SLUG="${CLIENT_PACK_SLUG:-mc-fantasy}"
DIST_DIR="${DIST_DIR:-dist}"
PACK_URL="${PACK_URL:-https://usersina.github.io/mc-fantasy-packwiz/stable/pack.toml}"
JAVA21="${JAVA21:-/usr/lib/jvm/java-21-openjdk/bin/java}"
PACKWIZ_INSTALLER_VERSION="${PACKWIZ_INSTALLER_VERSION:-v0.0.3}"
PACKWIZ_INSTALLER_URL="${PACKWIZ_INSTALLER_URL:-https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/${PACKWIZ_INSTALLER_VERSION}/packwiz-installer-bootstrap.jar}"
PACKWIZ_INSTALLER_CACHE="${PACKWIZ_INSTALLER_CACHE:-$REPO_DIR/.cache/packwiz-installer-bootstrap-${PACKWIZ_INSTALLER_VERSION}.jar}"
PACKWIZ_INSTALLER_MAIN_JAR="${PACKWIZ_INSTALLER_MAIN_JAR:-}"
PACKWIZ_INSTALLER_UPDATE_URL="${PACKWIZ_INSTALLER_UPDATE_URL:-https://api.github.com/repos/usersina/mc-fantasy-packwiz/releases/tags/client-stable}"
PACKWIZ_SOURCE_COMMIT="${PACKWIZ_SOURCE_COMMIT:-dfd8b68a4796c763e25bad50265ea1f1233e24f1}"
PACKWIZ_INSTALLER_SOURCE_COMMIT="${PACKWIZ_INSTALLER_SOURCE_COMMIT:-7420866dfc6ae1f68079a166e9804b7ec31a59ca}"
AUTH_TOOLS_DIR="${AUTH_TOOLS_DIR:-$REPO_DIR/dist/tools}"
JAVA17_HOME="${JAVA17_HOME:-/usr/lib/jvm/java-17-openjdk}"
REPORT_DIR="${REPORT_DIR:-$REPO_DIR/dist/inspect}"
ACTION="${1:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <site|export-client|smoke-update|inspect|client-test|build-auth-tools>

Actions:
  site                Refresh Packwiz and build the hosted stable Packwiz site.
  export-client       Refresh Packwiz and export the stable Prism/Freesm .mrpack.
  smoke-update        Install the client pack into a temp folder and verify basics.
  inspect             Inspect mods, materialized packs, launcher instances, or generated server configs.
  client-test         Bootstrap, sync, or launch a Prism/Freesm maintainer test client.
  build-auth-tools    Build pinned Packwiz tools with CurseForge environment-key support.

Inspect examples:
  INSPECT=mod MOD=mods/beltborne-lanterns.pw.toml $(basename "$0") inspect
  INSPECT=instance INSTANCE_MC_DIR=/path/to/instance/minecraft $(basename "$0") inspect
  INSPECT=pack PACK_URL=http://127.0.0.1:8081/stable/pack.toml $(basename "$0") inspect
  INSPECT=server-generated $(basename "$0") inspect

Client test examples:
  $(basename "$0") client-test
  CLIENT_INSTANCE_ID=FantasyDev $(basename "$0") client-test
  CLIENT_INSTANCE_ID=FantasyDev LAUNCH=false $(basename "$0") client-test
  RESET=true $(basename "$0") client-test

Client test options:
  CLIENT_TEST_IMPORT_SLUG=mc-fantasy-dev sets the bootstrap .mrpack filename.
  CLIENT_TEST_DISABLE_PRELAUNCH=false keeps an existing launcher pre-launch command.
EOF
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command_name"
    exit 1
  fi
}

cmd_build_auth_tools() {
  local work_dir
  local packwiz_dir
  local installer_dir
  local encoded_key
  local key_source

  require_command git
  require_command go
  require_command base64

  if [ -z "${CURSEFORGE_API_KEY:-}" ]; then
    echo "ERROR: CURSEFORGE_API_KEY is required to build authenticated Packwiz tools"
    exit 1
  fi

  if [ ! -x "$JAVA17_HOME/bin/java" ]; then
    echo "ERROR: Packwiz Installer build requires Java 17 at: $JAVA17_HOME/bin/java"
    exit 1
  fi

  work_dir="$(mktemp -d)"
  packwiz_dir="$work_dir/packwiz"
  installer_dir="$work_dir/packwiz-installer"
  trap 'rm -rf "${work_dir:-}"' EXIT

  mkdir -p "$AUTH_TOOLS_DIR"

  echo "==> Building Packwiz CLI from pinned commit"
  git clone --quiet --filter=blob:none --no-checkout https://github.com/packwiz/packwiz.git "$packwiz_dir"
  git -C "$packwiz_dir" checkout --quiet --detach "$PACKWIZ_SOURCE_COMMIT"
  git -C "$packwiz_dir" apply "$REPO_DIR/scripts/patches/packwiz-curseforge-auth.patch"
  (
    cd "$packwiz_dir"
    go build -trimpath -o "$AUTH_TOOLS_DIR/packwiz" .
  )

  echo "==> Building Packwiz Installer from pinned commit"
  git clone --quiet --filter=blob:none --no-checkout https://github.com/packwiz/packwiz-installer.git "$installer_dir"
  git -C "$installer_dir" checkout --quiet --detach "$PACKWIZ_INSTALLER_SOURCE_COMMIT"
  git -C "$installer_dir" apply "$REPO_DIR/scripts/patches/packwiz-installer-curseforge-auth.patch"
  encoded_key="$(printf '%s' "$CURSEFORGE_API_KEY" | base64 | tr -d '\n')"
  key_source="$installer_dir/src/main/kotlin/link/infra/packwiz/installer/metadata/curseforge/CurseForgeApiKey.kt"
  {
    printf '%s\n' 'package link.infra.packwiz.installer.metadata.curseforge'
    printf '\n'
    printf '%s\n' 'import java.nio.charset.StandardCharsets'
    printf '%s\n' 'import java.util.Base64'
    printf '\n'
    printf '%s\n' 'internal object CurseForgeApiKey {'
    printf '\tval value = String(Base64.getDecoder().decode("%s"), StandardCharsets.UTF_8)\n' "$encoded_key"
    printf '%s\n' '}'
  } > "$key_source"
  (
    cd "$installer_dir"
    JAVA_HOME="$JAVA17_HOME" ./gradlew copyJar -PfantasyPackVersion=client-stable --no-daemon
  )
  cp -p "$installer_dir/build/dist/packwiz-installer.jar" "$AUTH_TOOLS_DIR/packwiz-installer.jar"

  echo "==> Built authenticated Packwiz tools:"
  echo "    $AUTH_TOOLS_DIR/packwiz"
  echo "    $AUTH_TOOLS_DIR/packwiz-installer.jar"

  trap - EXIT
  rm -rf "$work_dir"
}

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

safe_rm_rf() {
  local path="$1"

  case "$path" in
    ""|"."|"./"|"/"|"$REPO_DIR"|"$REPO_DIR/")
      echo "ERROR: refusing unsafe rm path: $path"
      exit 1
      ;;
  esac

  rm -rf "$path"
}

pack_value() {
  local key="$1"

  awk -F'"' -v key="$key" '$1 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$REPO_DIR/pack.toml"
}

toml_value() {
  local file="$1"
  local key="$2"

  awk -F'"' -v key="$key" '$1 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$file"
}

expected_client_mod_paths() {
  local metadata_file
  local side
  local filename

  for metadata_file in "$REPO_DIR"/mods/*.pw.toml; do
    side="$(toml_value "$metadata_file" side)"
    if [ "$side" = "server" ]; then
      continue
    fi

    filename="$(toml_value "$metadata_file" filename)"
    if [ -n "$filename" ]; then
      printf "mods/%s\n" "$filename"
    fi
  done

  find "$REPO_DIR/mods" -maxdepth 1 -type f -name '*.jar' -printf 'mods/%f\n'
}

verify_client_export() {
  local archive="$1"
  local temp_dir
  local missing
  local expected_count

  require_command jq
  require_command unzip

  if ! unzip -tq "$archive" >/dev/null; then
    echo "ERROR: exported client archive is not a valid zip: $archive"
    exit 1
  fi

  temp_dir="$(mktemp -d)"

  expected_client_mod_paths | sort -u > "$temp_dir/expected.txt"
  {
    unzip -p "$archive" modrinth.index.json | jq -r '.files[].path'
    unzip -Z1 "$archive" | awk '
      /^(overrides|client-overrides)\/mods\/.*\.jar$/ {
        sub(/^(overrides|client-overrides)\//, "")
        print
      }
    '
  } | sort -u > "$temp_dir/present.txt"

  missing="$(comm -23 "$temp_dir/expected.txt" "$temp_dir/present.txt")"
  if [ -n "$missing" ]; then
    echo "ERROR: exported client archive is missing expected mod jars:"
    printf '%s\n' "$missing" | sed 's/^/  - /'
    rm -rf "$temp_dir"
    exit 1
  fi

  expected_count="$(wc -l < "$temp_dir/expected.txt" | tr -d ' ')"
  echo "==> Verified client export contains all $expected_count expected mod jars"
  rm -rf "$temp_dir"
}

sanitize_name() {
  printf "%s\n" "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

repo_status() {
  local rel="$1"

  if git -C "$REPO_DIR" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
    printf "tracked"
  elif [ -e "$REPO_DIR/$rel" ]; then
    printf "present, untracked"
  else
    printf "missing"
  fi
}

md_escape() {
  printf "%s" "$1" | sed 's/|/\\|/g'
}

build_site() {
  local site_root
  local count=0
  local file

  cd "$REPO_DIR"

  case "$SITE_DIR" in
    ""|"."|"./"|"/"|"$REPO_DIR"|"$REPO_DIR/")
      echo "ERROR: refusing unsafe SITE_DIR: $SITE_DIR"
      exit 1
      ;;
  esac

  site_root="$(dirname "$SITE_DIR")"
  case "$site_root" in
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

  safe_rm_rf "$SITE_DIR"
  mkdir -p "$SITE_DIR" "$site_root"

  cp -p "$SITE_INDEX_SOURCE" "$site_root/index.html"
  cp -p pack.toml index.toml "$SITE_DIR/"

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
  echo "    $site_root/index.html"
  echo "==> Copied $count indexed files plus pack.toml and index.toml"
}

cmd_site() {
  cd "$REPO_DIR"
  packwiz refresh
  build_site
}

cmd_export_client() {
  local version
  local mc_version
  local output

  cd "$REPO_DIR"

  version="$(pack_value version)"
  mc_version="$(pack_value minecraft)"

  if [ -z "$version" ] || [ -z "$mc_version" ]; then
    echo "ERROR: could not read version or minecraft from pack.toml"
    exit 1
  fi

  packwiz refresh

  output="${DIST_DIR%/}/${CLIENT_PACK_SLUG}-stable.mrpack"
  mkdir -p "$DIST_DIR"
  rm -f "$output"
  packwiz modrinth export -o "$output"
  verify_client_export "$output"

  echo "==> Wrote $output"

  if [ "${GITHUB_OUTPUT:-}" != "" ]; then
    {
      echo "pack_version=$version"
      echo "minecraft_version=$mc_version"
      echo "asset_name=$(basename "$output")"
      echo "asset_path=$output"
    } >> "$GITHUB_OUTPUT"
  fi
}

client_test_dir() {
  local dir="${CLIENT_TEST_DIR:-$REPO_DIR/dist/client-test}"

  case "$dir" in
    /*) printf "%s\n" "$dir" ;;
    *) printf "%s\n" "$REPO_DIR/$dir" ;;
  esac
}

client_test_site_dir() {
  printf "%s\n" "$(client_test_dir)/site/stable"
}

client_test_mc_dir_default() {
  printf "%s\n" "$(client_test_dir)/minecraft"
}

client_test_instance_id_file() {
  printf "%s\n" "$(client_test_dir)/instance-id"
}

is_truthy() {
  case "${1:-}" in
    true|TRUE|True|yes|YES|Yes|1)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

reset_remembered_client_instance() {
  local state_file

  state_file="$(client_test_instance_id_file)"
  if [ -f "$state_file" ]; then
    rm -f "$state_file"
    echo "==> Forgot remembered client test instance"
  fi
}

load_remembered_client_instance() {
  local state_file

  if [ -n "${CLIENT_INSTANCE_ID:-}" ]; then
    return 0
  fi

  state_file="$(client_test_instance_id_file)"
  if [ ! -f "$state_file" ]; then
    return 0
  fi

  CLIENT_INSTANCE_ID="$(sed -n '1p' "$state_file" | tr -d '\r\n')"
  if [ -n "$CLIENT_INSTANCE_ID" ]; then
    echo "==> Using remembered client test instance:"
    echo "    $CLIENT_INSTANCE_ID"
  fi
}

remember_client_instance() {
  local state_file

  if [ -z "${CLIENT_INSTANCE_ID:-}" ]; then
    return 0
  fi

  state_file="$(client_test_instance_id_file)"
  mkdir -p "$(dirname "$state_file")"
  printf "%s\n" "$CLIENT_INSTANCE_ID" > "$state_file"
  echo "==> Remembered client test instance:"
  echo "    $CLIENT_INSTANCE_ID"
}

discover_default_client_test_instance() {
  local default_id="${CLIENT_TEST_IMPORT_SLUG:-mc-fantasy-dev}"
  local mc_dir

  if [ -n "${CLIENT_INSTANCE_ID:-}" ] || [ -n "${INSTANCE_MC_DIR:-}" ]; then
    return 0
  fi

  if mc_dir="$(resolve_instance_mc_dir "$default_id")"; then
    CLIENT_INSTANCE_ID="$default_id"
    echo "==> Found existing client test instance:"
    echo "    $CLIENT_INSTANCE_ID"
    echo "==> Minecraft folder:"
    echo "    $mc_dir"
    remember_client_instance
  fi
}

resolve_instance_mc_dir() {
  local instance_id="$1"
  local root
  local instance_dir
  local mc_dir
  local roots=()

  if [ -n "${CLIENT_LAUNCHER_ROOT:-}" ]; then
    roots+=("$CLIENT_LAUNCHER_ROOT")
  fi

  roots+=(
    "$HOME/.local/share/PrismLauncher"
    "$HOME/.local/share/FreesmLauncher"
    "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"
    "$HOME/.var/app/org.freesmlauncher.FreesmLauncher/data/FreesmLauncher"
  )

  for root in "${roots[@]}"; do
    instance_dir="$root/instances/$instance_id"
    if [ ! -d "$instance_dir" ]; then
      continue
    fi

    for mc_dir in "$instance_dir/.minecraft" "$instance_dir/minecraft"; do
      if [ -d "$mc_dir" ]; then
        printf "%s\n" "$mc_dir"
        return 0
      fi
    done

    mkdir -p "$instance_dir/.minecraft"
    printf "%s\n" "$instance_dir/.minecraft"
    return 0
  done

  return 1
}

client_target_mc_dir() {
  if [ -n "${INSTANCE_MC_DIR:-}" ]; then
    printf "%s\n" "$INSTANCE_MC_DIR"
    return 0
  fi

  if [ -n "${CLIENT_INSTANCE_ID:-}" ]; then
    if resolve_instance_mc_dir "$CLIENT_INSTANCE_ID"; then
      return 0
    fi

    echo "ERROR: could not find launcher instance folder for CLIENT_INSTANCE_ID=$CLIENT_INSTANCE_ID" >&2
    echo "Pass INSTANCE_MC_DIR=/path/to/instance/.minecraft, set CLIENT_LAUNCHER_ROOT=/path/to/launcher/root, or run RESET=true to forget it." >&2
    exit 1
  fi

  client_test_mc_dir_default
}

disable_public_packwiz_prelaunch_for_test() {
  local mc_dir="$1"
  local instance_dir
  local cfg
  local backup
  local tmp

  if ! is_truthy "${CLIENT_TEST_DISABLE_PRELAUNCH:-true}"; then
    return 0
  fi

  case "$(basename "$mc_dir")" in
    .minecraft|minecraft)
      instance_dir="$(dirname "$mc_dir")"
      ;;
    *)
      return 0
      ;;
  esac

  cfg="$instance_dir/instance.cfg"
  if [ ! -f "$cfg" ]; then
    return 0
  fi

  if ! grep -q '^PreLaunchCommand=.*packwiz-installer.*usersina.github.io/mc-fantasy-packwiz/stable/pack.toml' "$cfg"; then
    return 0
  fi

  backup="$cfg.client-test-prelaunch.bak"
  if [ ! -f "$backup" ]; then
    cp -p "$cfg" "$backup"
  fi

  tmp="$(mktemp "${cfg}.tmp.XXXXXX")"
  awk '
    /^PreLaunchCommand=/ {
      print "PreLaunchCommand="
      next
    }
    { print }
  ' "$cfg" > "$tmp"
  mv "$tmp" "$cfg"

  echo "==> Disabled public Packwiz pre-launch updater for maintainer test instance"
  echo "    $cfg"
  echo "==> Backup:"
  echo "    $backup"
}

start_client_site_server() {
  local site_root="$1"
  local port="$2"
  local log_file="$3"

  require_command python3

  (
    cd "$site_root"
    python3 -m http.server "$port" --bind 127.0.0.1 > "$log_file" 2>&1
  ) &
  CLIENT_SITE_SERVER_PID="$!"
}

stop_client_site_server() {
  if [ -n "${CLIENT_SITE_SERVER_PID:-}" ] && kill -0 "$CLIENT_SITE_SERVER_PID" >/dev/null 2>&1; then
    kill "$CLIENT_SITE_SERVER_PID" >/dev/null 2>&1 || true
    wait "$CLIENT_SITE_SERVER_PID" >/dev/null 2>&1 || true
  fi
}

sync_client_test_pack() {
  local target_dir="$1"
  local test_dir
  local site_dir
  local site_root
  local old_site_dir
  local port="${CLIENT_TEST_PORT:-8082}"
  local url
  local log_file

  cd "$REPO_DIR"

  test_dir="$(client_test_dir)"
  site_dir="$(client_test_site_dir)"
  site_root="$(dirname "$site_dir")"
  log_file="$test_dir/http-server.log"

  safe_rm_rf "$site_dir"
  mkdir -p "$target_dir" "$test_dir"

  echo "==> Refreshing Packwiz index"
  packwiz refresh

  echo "==> Building temporary local Packwiz site"
  old_site_dir="$SITE_DIR"
  SITE_DIR="$site_dir"
  build_site
  SITE_DIR="$old_site_dir"

  url="http://127.0.0.1:${port}/stable/pack.toml"
  echo "==> Serving temporary Packwiz site:"
  echo "    $url"
  start_client_site_server "$site_root" "$port" "$log_file"
  trap 'status=$?; stop_client_site_server; exit "$status"' EXIT

  if ! wait_for_http "$url"; then
    echo "ERROR: temporary Packwiz site did not start"
    echo "==> Server log:"
    sed -n '1,120p' "$log_file" 2>/dev/null || true
    exit 1
  fi

  install_packwiz_client "$target_dir" "$url"
  cp -p "$PACKWIZ_INSTALLER_CACHE" "$target_dir/packwiz-installer-bootstrap.jar"

  trap - EXIT
  stop_client_site_server

  echo "==> Synced client Minecraft folder:"
  echo "    $target_dir"
}

launcher_args_common() {
  if [ -n "${CLIENT_LAUNCHER_ROOT:-}" ]; then
    printf "%s\0%s\0" "--dir" "$CLIENT_LAUNCHER_ROOT"
  fi
}

should_launch_client() {
  case "${LAUNCH:-true}" in
    false|FALSE|False|no|NO|No|0)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

run_launcher() {
  local -a args=("$@")
  local launcher="${CLIENT_LAUNCHER:-}"
  local bin
  local app_id
  local -a bins=(prismlauncher PrismLauncher freesmlauncher FreesmLauncher)
  local -a app_ids=(org.prismlauncher.PrismLauncher org.freesmlauncher.FreesmLauncher)

  if [ -n "$launcher" ]; then
    if command -v "$launcher" >/dev/null 2>&1; then
      "$launcher" "${args[@]}"
      return 0
    fi

    if command -v flatpak >/dev/null 2>&1 && flatpak info "$launcher" >/dev/null 2>&1; then
      flatpak run "$launcher" "${args[@]}"
      return 0
    fi

    echo "ERROR: CLIENT_LAUNCHER is not an executable or Flatpak app id: $launcher"
    exit 1
  fi

  for bin in "${bins[@]}"; do
    if command -v "$bin" >/dev/null 2>&1; then
      "$bin" "${args[@]}"
      return 0
    fi
  done

  if command -v flatpak >/dev/null 2>&1; then
    for app_id in "${app_ids[@]}"; do
      if flatpak info "$app_id" >/dev/null 2>&1; then
        flatpak run "$app_id" "${args[@]}"
        return 0
      fi
    done
  fi

  echo "ERROR: could not find Prism Launcher or Freesm Launcher"
  echo "Set CLIENT_LAUNCHER to an executable name/path or Flatpak app id."
  echo "Examples:"
  echo "  CLIENT_LAUNCHER=prismlauncher"
  echo "  CLIENT_LAUNCHER=org.prismlauncher.PrismLauncher"
  echo "  CLIENT_LAUNCHER=org.freesmlauncher.FreesmLauncher"
  exit 1
}

cmd_client_test_bootstrap() {
  local output
  local import_output
  local import_slug="${CLIENT_TEST_IMPORT_SLUG:-mc-fantasy-dev}"
  local remembered_bootstrap=false
  local -a args=()
  local arg

  cmd_export_client

  output="${DIST_DIR%/}/${CLIENT_PACK_SLUG}-stable.mrpack"
  import_output="${DIST_DIR%/}/${import_slug}.mrpack"
  if [ "$import_output" != "$output" ]; then
    cp -p "$output" "$import_output"
  fi

  echo "==> Test client bootstrap .mrpack:"
  echo "    $import_output"

  if should_launch_client; then
    while IFS= read -r -d '' arg; do
      args+=("$arg")
    done < <(launcher_args_common)
    args+=("--import" "$REPO_DIR/$import_output")

    echo "==> Opening launcher import flow"
    run_launcher "${args[@]}"
    CLIENT_INSTANCE_ID="$import_slug"
    remember_client_instance
    remembered_bootstrap=true
  else
    echo "==> Launch disabled by LAUNCH=false"
  fi

  if [ "$remembered_bootstrap" = "true" ]; then
    echo "==> After importing as ${import_slug}, plain 'task client:test' will reuse it."
    echo "==> If Freesm picked a different folder name, run:"
    echo "    task client:test CLIENT_INSTANCE_ID=<actual-instance-folder-name>"
  else
    echo "==> After importing, note the instance folder name and run:"
    echo "    task client:test CLIENT_INSTANCE_ID=${import_slug}"
    echo "==> If Freesm picked a different folder name, use that exact folder name instead."
    echo "==> After that, plain 'task client:test' will reuse the remembered instance."
  fi
}

cmd_client_test() {
  local target_dir
  local -a args=()
  local arg

  if is_truthy "${RESET:-false}"; then
    reset_remembered_client_instance
  else
    load_remembered_client_instance
    discover_default_client_test_instance
  fi

  if [ -z "${CLIENT_INSTANCE_ID:-}" ] && [ -z "${INSTANCE_MC_DIR:-}" ]; then
    cmd_client_test_bootstrap
    return 0
  fi

  target_dir="$(client_target_mc_dir)"
  sync_client_test_pack "$target_dir"
  remember_client_instance
  disable_public_packwiz_prelaunch_for_test "$target_dir"

  if ! should_launch_client; then
    echo "==> Launch disabled by LAUNCH=false"
    return 0
  fi

  if [ -z "${CLIENT_INSTANCE_ID:-}" ]; then
    echo "ERROR: launching requires CLIENT_INSTANCE_ID=<launcher instance folder name>" >&2
    echo "The pack was synced to: $target_dir" >&2
    echo "Pass CLIENT_INSTANCE_ID, or run with LAUNCH=false for sync-only." >&2
    exit 1
  fi

  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < <(launcher_args_common)
  args+=("--launch" "$CLIENT_INSTANCE_ID")

  if [ -n "${CLIENT_SERVER:-}" ]; then
    args+=("--server" "$CLIENT_SERVER")
  fi

  echo "==> Launching client test instance:"
  echo "    $CLIENT_INSTANCE_ID"
  run_launcher "${args[@]}"
}

install_packwiz_client() {
  local target_dir="$1"
  local pack_url="$2"
  local -a installer_args=(-g -s client "$pack_url")

  require_java21
  download_if_missing "$PACKWIZ_INSTALLER_CACHE" "$PACKWIZ_INSTALLER_URL"
  mkdir -p "$target_dir"

  if [ -n "$PACKWIZ_INSTALLER_MAIN_JAR" ]; then
    if [ ! -f "$PACKWIZ_INSTALLER_MAIN_JAR" ]; then
      echo "ERROR: Packwiz Installer main jar not found: $PACKWIZ_INSTALLER_MAIN_JAR"
      exit 1
    fi
    installer_args=(--bootstrap-no-update --bootstrap-main-jar "$PACKWIZ_INSTALLER_MAIN_JAR" "${installer_args[@]}")
  else
    installer_args=(--bootstrap-update-url "$PACKWIZ_INSTALLER_UPDATE_URL" "${installer_args[@]}")
  fi

  (
    cd "$target_dir"
    "$JAVA21" -jar "$PACKWIZ_INSTALLER_CACHE" "${installer_args[@]}"
  )
}

require_path_in_dir() {
  local base_dir="$1"
  local path="$2"

  if [ ! -e "$base_dir/$path" ]; then
    echo "ERROR: expected path is missing: $path"
    exit 1
  fi
}

require_mod_match_in_dir() {
  local base_dir="$1"
  local label="$2"
  local pattern="$3"

  if ! find "$base_dir/mods" -type f -iname "$pattern" -print -quit | grep -q .; then
    echo "ERROR: expected mod jar is missing: $label ($pattern)"
    exit 1
  fi
}

cmd_smoke_update() {
  local smoke_dir="${SMOKE_DIR:-}"
  local created_smoke_dir=false
  local mod_count

  if [ "$smoke_dir" = "" ]; then
    smoke_dir="$(mktemp -d)"
    created_smoke_dir=true
  else
    mkdir -p "$smoke_dir"
  fi

  cleanup_smoke() {
    local status="${1:-1}"
    local cleanup_dir="${2:-}"
    local cleanup_created="${3:-false}"

    if [ -z "$cleanup_dir" ]; then
      return 0
    fi

    if [ "$status" -eq 0 ] && [ "$cleanup_created" = "true" ] && [ "${KEEP_SMOKE_DIR:-false}" != "true" ]; then
      rm -rf "$cleanup_dir"
      return 0
    fi

    echo "==> Smoke client folder retained:"
    echo "    $cleanup_dir"
  }
  trap 'status=$?; cleanup_smoke "$status" "${smoke_dir:-}" "${created_smoke_dir:-false}"' EXIT

  echo "==> Smoke client folder:"
  echo "    $smoke_dir"
  echo "==> Pack URL:"
  echo "    $PACK_URL"

  install_packwiz_client "$smoke_dir" "$PACK_URL"

  require_path_in_dir "$smoke_dir" "mods"
  require_path_in_dir "$smoke_dir" "defaultconfigs/waystones-common.toml"
  require_path_in_dir "$smoke_dir" "config/defaultoptions/keybindings.txt"
  require_path_in_dir "$smoke_dir" "config/paxi/datapacks/minecraft_convenience_recipes/pack.mcmeta"
  require_mod_match_in_dir "$smoke_dir" "Configured" "configured-*.jar"
  require_mod_match_in_dir "$smoke_dir" "Default Options" "defaultoptions-*.jar"
  require_mod_match_in_dir "$smoke_dir" "More Dragon Eggs" "moredragoneggs-*.jar"

  mod_count="$(find "$smoke_dir/mods" -type f -name '*.jar' | wc -l)"

  echo "==> Client updater smoke test passed"
  echo "==> Installed $mod_count mod jars"
  trap - EXIT
  cleanup_smoke 0 "$smoke_dir" "$created_smoke_dir"
}

glfw_key_name() {
  local code="$1"

  case "$code" in
    -1|0) printf "key.keyboard.unknown" ;;
    32) printf "key.keyboard.space" ;;
    39) printf "key.keyboard.apostrophe" ;;
    44) printf "key.keyboard.comma" ;;
    45) printf "key.keyboard.minus" ;;
    46) printf "key.keyboard.period" ;;
    47) printf "key.keyboard.slash" ;;
    48) printf "key.keyboard.0" ;;
    49) printf "key.keyboard.1" ;;
    50) printf "key.keyboard.2" ;;
    51) printf "key.keyboard.3" ;;
    52) printf "key.keyboard.4" ;;
    53) printf "key.keyboard.5" ;;
    54) printf "key.keyboard.6" ;;
    55) printf "key.keyboard.7" ;;
    56) printf "key.keyboard.8" ;;
    57) printf "key.keyboard.9" ;;
    59) printf "key.keyboard.semicolon" ;;
    61) printf "key.keyboard.equal" ;;
    65) printf "key.keyboard.a" ;;
    66) printf "key.keyboard.b" ;;
    67) printf "key.keyboard.c" ;;
    68) printf "key.keyboard.d" ;;
    69) printf "key.keyboard.e" ;;
    70) printf "key.keyboard.f" ;;
    71) printf "key.keyboard.g" ;;
    72) printf "key.keyboard.h" ;;
    73) printf "key.keyboard.i" ;;
    74) printf "key.keyboard.j" ;;
    75) printf "key.keyboard.k" ;;
    76) printf "key.keyboard.l" ;;
    77) printf "key.keyboard.m" ;;
    78) printf "key.keyboard.n" ;;
    79) printf "key.keyboard.o" ;;
    80) printf "key.keyboard.p" ;;
    81) printf "key.keyboard.q" ;;
    82) printf "key.keyboard.r" ;;
    83) printf "key.keyboard.s" ;;
    84) printf "key.keyboard.t" ;;
    85) printf "key.keyboard.u" ;;
    86) printf "key.keyboard.v" ;;
    87) printf "key.keyboard.w" ;;
    88) printf "key.keyboard.x" ;;
    89) printf "key.keyboard.y" ;;
    90) printf "key.keyboard.z" ;;
    91) printf "key.keyboard.left.bracket" ;;
    92) printf "key.keyboard.backslash" ;;
    93) printf "key.keyboard.right.bracket" ;;
    96) printf "key.keyboard.grave.accent" ;;
    256) printf "key.keyboard.escape" ;;
    257) printf "key.keyboard.enter" ;;
    258) printf "key.keyboard.tab" ;;
    259) printf "key.keyboard.backspace" ;;
    260) printf "key.keyboard.insert" ;;
    261) printf "key.keyboard.delete" ;;
    262) printf "key.keyboard.right" ;;
    263) printf "key.keyboard.left" ;;
    264) printf "key.keyboard.down" ;;
    265) printf "key.keyboard.up" ;;
    280) printf "key.keyboard.caps.lock" ;;
    290) printf "key.keyboard.f1" ;;
    291) printf "key.keyboard.f2" ;;
    292) printf "key.keyboard.f3" ;;
    293) printf "key.keyboard.f4" ;;
    294) printf "key.keyboard.f5" ;;
    295) printf "key.keyboard.f6" ;;
    296) printf "key.keyboard.f7" ;;
    297) printf "key.keyboard.f8" ;;
    298) printf "key.keyboard.f9" ;;
    299) printf "key.keyboard.f10" ;;
    300) printf "key.keyboard.f11" ;;
    301) printf "key.keyboard.f12" ;;
    340) printf "key.keyboard.left.shift" ;;
    341) printf "key.keyboard.left.control" ;;
    342) printf "key.keyboard.left.alt" ;;
    343) printf "key.keyboard.left.win" ;;
    344) printf "key.keyboard.right.shift" ;;
    345) printf "key.keyboard.right.control" ;;
    346) printf "key.keyboard.right.alt" ;;
    347) printf "key.keyboard.right.win" ;;
    *) printf "GLFW_%s" "$code" ;;
  esac
}

generate_javap_text() {
  local jar_file="$1"
  local output="$2"
  local class_limit="${JAVAP_CLASS_LIMIT:-300}"
  local count=0
  local class_path
  local class_name

  : > "$output"

  if ! command -v javap >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r class_path; do
    class_name="${class_path%.class}"
    class_name="${class_name//\//.}"
    {
      echo "===== $class_name ====="
      javap -classpath "$jar_file" -c -p "$class_name" 2>/dev/null || true
      echo
    } >> "$output"
    count=$((count + 1))
    if [ "$count" -ge "$class_limit" ]; then
      break
    fi
  done < <(jar tf "$jar_file" | grep '\.class$' | grep -Ei '(client|key|config|common|forge|neoforge|fabric)' | sort)
}

generate_javap_verbose_text() {
  local jar_file="$1"
  local output="$2"
  local class_limit="${JAVAP_VERBOSE_CLASS_LIMIT:-180}"
  local count=0
  local class_path
  local class_name

  : > "$output"

  if ! command -v javap >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r class_path; do
    class_name="${class_path%.class}"
    class_name="${class_name//\//.}"
    {
      echo "===== $class_name ====="
      javap -classpath "$jar_file" -v -p "$class_name" 2>/dev/null || true
      echo
    } >> "$output"
    count=$((count + 1))
    if [ "$count" -ge "$class_limit" ]; then
      break
    fi
  done < <(jar tf "$jar_file" | grep '\.class$' | grep -Ei '(config|client)' | sort)
}

detect_default_key_code() {
  local javap_file="$1"
  local translation_key="$2"

  if [ ! -s "$javap_file" ]; then
    return 0
  fi

  awk -v key="$translation_key" '
    index($0, "String " key) > 0 { seen = 24; next }
    seen > 0 {
      if ($0 ~ /bipush[[:space:]]+-?[0-9]+/) {
        print $NF
        exit
      }
      if ($0 ~ /sipush[[:space:]]+-?[0-9]+/) {
        print $NF
        exit
      }
      if ($0 ~ /iconst_m1/) {
        print "-1"
        exit
      }
      if ($0 ~ /iconst_[0-5]/) {
        sub(/^.*iconst_/, "", $0)
        sub(/[^0-9].*$/, "", $0)
        print $0
        exit
      }
      seen--
    }
  ' "$javap_file"
}

extract_lang_keys() {
  local jar_file="$1"
  local output="$2"
  local entry

  : > "$output"
  while IFS= read -r entry; do
    unzip -p "$jar_file" "$entry" 2>/dev/null \
      | jq -r 'to_entries[] | select(.key | startswith("key.") or startswith("text.autoconfig.")) | [.key, (.value | tostring)] | @tsv' \
      >> "$output" 2>/dev/null || true
  done < <(jar tf "$jar_file" | grep -E '^assets/.*/lang/en_us\.json$' | sort)
}

config_extension_from_jar() {
  local jar_file="$1"
  local jar_strings

  jar_strings="$(unzip -p "$jar_file" 2>/dev/null | strings || true)"

  if grep -q 'Toml4jConfigSerializer' <<< "$jar_strings"; then
    printf "toml"
  elif grep -q 'JanksonConfigSerializer' <<< "$jar_strings"; then
    printf "json5"
  else
    printf "json"
  fi
}

suggest_owner_path() {
  local path="$1"
  local base

  base="$(basename "$path")"
  case "$path" in
    defaultconfigs/*)
      printf "%s" "$path"
      ;;
    world/serverconfig/*|*/serverconfig/*)
      printf "defaultconfigs/%s" "$base"
      ;;
    config/*)
      printf "%s" "$path"
      ;;
    *-server.toml)
      printf "defaultconfigs/%s" "$base"
      ;;
    *)
      printf "config/%s" "$base"
      ;;
  esac
}

add_config_candidate() {
  local output="$1"
  local candidate="$2"
  local evidence="$3"
  local owner_path
  local status

  candidate="${candidate#./}"
  owner_path="$(suggest_owner_path "$candidate")"
  status="$(repo_status "$owner_path")"
  printf "%s\t%s\t%s\t%s\n" "$candidate" "$evidence" "$owner_path" "$status" >> "$output"
}

collect_config_candidates() {
  local jar_file="$1"
  local lang_tsv="$2"
  local javap_verbose_file="$3"
  local output="$4"
  local ext
  local serializer_note
  local name
  local string_candidate

  : > "$output"
  ext="$(config_extension_from_jar "$jar_file")"
  serializer_note="lang text.autoconfig + ${ext} serializer heuristic"

  awk -F'\t' '$1 ~ /^text\.autoconfig\.[^.]+\./ {
    key = $1
    sub(/^text\.autoconfig\./, "", key)
    sub(/\..*$/, "", key)
    print key
  }' "$lang_tsv" | sort -u | while IFS= read -r name; do
    [ -n "$name" ] || continue
    add_config_candidate "$output" "config/${name}.${ext}" "$serializer_note"
  done

  awk '
    /me\.shedaniel\.autoconfig\.annotation\.Config\(/ { in_config = 1; next }
    in_config && /name="/ {
      value = $0
      sub(/^.*name="/, "", value)
      sub(/".*$/, "", value)
      print value
      in_config = 0
    }
  ' "$javap_verbose_file" | sort -u | while IFS= read -r name; do
    [ -n "$name" ] || continue
    add_config_candidate "$output" "config/${name}.${ext}" "AutoConfig annotation + ${ext} serializer heuristic"
  done

  while IFS= read -r string_candidate; do
    [ -n "$string_candidate" ] || continue
    add_config_candidate "$output" "$string_candidate" "class constant"
  done < <(
    { grep -E '// String config/[A-Za-z0-9_.-]+\.(json5?|toml|properties|cfg)$|ConstantValue: String config/[A-Za-z0-9_.-]+\.(json5?|toml|properties|cfg)$' "$javap_verbose_file" || true; } \
      | sed 's/^.*String //' \
      | sort -u
  )

  while IFS= read -r string_candidate; do
    [ -n "$string_candidate" ] || continue
    case "$string_candidate" in
      */*) add_config_candidate "$output" "$string_candidate" "jar string" ;;
      *) add_config_candidate "$output" "config/$string_candidate" "jar string" ;;
    esac
  done < <(
    unzip -p "$jar_file" 2>/dev/null \
      | strings \
      | sed 's/PK$//' \
      | { grep -E '^config/[A-Za-z0-9_.-]+\.(json5?|toml|properties|cfg)$|^[A-Za-z0-9_.-]+-(client|common|server)\.toml$' || true; } \
      | sort -u
  )

  if [ -s "$output" ]; then
    sort -t $'\t' -k1,1 -u "$output" -o "$output"
  fi
}

resolve_mod_source() {
  local mod_ref="$1"
  local cache_dir="$REPORT_DIR/cache"
  local url
  local filename
  local hash_format
  local expected_hash
  local actual_hash
  local version_json
  local mc_version
  local loader="neoforge"
  local slug

  INSPECT_NAME=""
  INSPECT_SOURCE="$mod_ref"
  INSPECT_SIDE=""
  INSPECT_JAR=""

  mkdir -p "$cache_dir"

  if [ -f "$mod_ref" ]; then
    case "$mod_ref" in
      *.jar)
        INSPECT_JAR="$mod_ref"
        INSPECT_NAME="$(basename "$mod_ref" .jar)"
        return 0
        ;;
      *.pw.toml)
        INSPECT_NAME="$(toml_value "$mod_ref" name)"
        filename="$(toml_value "$mod_ref" filename)"
        url="$(toml_value "$mod_ref" url)"
        INSPECT_SIDE="$(toml_value "$mod_ref" side)"
        hash_format="$(toml_value "$mod_ref" hash-format)"
        expected_hash="$(toml_value "$mod_ref" hash)"

        if [ -z "$filename" ] || [ -z "$url" ]; then
          echo "ERROR: could not read filename/url from $mod_ref"
          exit 1
        fi

        INSPECT_JAR="$cache_dir/$filename"
        download_if_missing "$INSPECT_JAR" "$url"

        if [ -n "$expected_hash" ]; then
          case "$hash_format" in
            sha512)
              actual_hash="$(sha512sum "$INSPECT_JAR" | awk '{ print $1 }')"
              ;;
            sha256)
              actual_hash="$(sha256sum "$INSPECT_JAR" | awk '{ print $1 }')"
              ;;
            *)
              actual_hash=""
              ;;
          esac

          if [ -n "$actual_hash" ] && [ "$actual_hash" != "$expected_hash" ]; then
            echo "ERROR: downloaded jar hash mismatch for $mod_ref"
            exit 1
          fi
        fi
        return 0
        ;;
      *)
        echo "ERROR: unsupported mod file: $mod_ref"
        exit 1
        ;;
    esac
  fi

  if printf "%s\n" "$mod_ref" | grep -Eq '^https?://.*\.jar($|[?#])'; then
    filename="$(basename "${mod_ref%%\?*}")"
    INSPECT_NAME="${filename%.jar}"
    INSPECT_JAR="$cache_dir/$filename"
    download_if_missing "$INSPECT_JAR" "$mod_ref"
    return 0
  fi

  if printf "%s\n" "$mod_ref" | grep -q 'modrinth.com/mod/'; then
    slug="$(printf "%s\n" "$mod_ref" | sed 's#.*modrinth.com/mod/##; s#[/?#].*##')"
  else
    slug="$mod_ref"
  fi

  mc_version="$(pack_value minecraft)"
  require_command jq
  version_json="$(curl -fsS --get \
    --data-urlencode "loaders=[\"$loader\"]" \
    --data-urlencode "game_versions=[\"$mc_version\"]" \
    "https://api.modrinth.com/v2/project/${slug}/version")"

  if [ "$(printf "%s\n" "$version_json" | jq 'length')" = "0" ]; then
    echo "ERROR: no Modrinth version found for $slug with loader=$loader minecraft=$mc_version"
    exit 1
  fi

  url="$(printf "%s\n" "$version_json" | jq -r '.[0].files | ((map(select(.primary == true))[0]) // .[0]) | .url')"
  filename="$(printf "%s\n" "$version_json" | jq -r '.[0].files | ((map(select(.primary == true))[0]) // .[0]) | .filename')"

  if [ -z "$url" ] || [ "$url" = "null" ] || [ -z "$filename" ] || [ "$filename" = "null" ]; then
    echo "ERROR: could not resolve a downloadable jar for Modrinth project: $slug"
    exit 1
  fi

  INSPECT_NAME="$slug"
  INSPECT_JAR="$cache_dir/$filename"
  download_if_missing "$INSPECT_JAR" "$url"
}

write_mod_report() {
  local report="$1"
  local jar_file="$2"
  local work_dir="$3"
  local lang_tsv="$work_dir/lang.tsv"
  local key_tsv="$work_dir/keys.tsv"
  local config_tsv="$work_dir/configs.tsv"
  local javap_file="$work_dir/javap.txt"
  local javap_verbose_file="$work_dir/javap-verbose.txt"
  local mod_meta="$work_dir/mod-meta.txt"
  local mod_ids="$work_dir/mod-ids.txt"
  local key
  local label
  local default_code
  local default_key
  local suggested
  local escaped_label
  local candidate
  local evidence
  local owner_path
  local status

  extract_lang_keys "$jar_file" "$lang_tsv"
  awk -F'\t' '$1 ~ /^key\./ && $1 !~ /^key\.categories\./ && $1 !~ /^key\.category\./ { print }' "$lang_tsv" > "$key_tsv"
  generate_javap_text "$jar_file" "$javap_file"
  generate_javap_verbose_text "$jar_file" "$javap_verbose_file"
  collect_config_candidates "$jar_file" "$lang_tsv" "$javap_verbose_file" "$config_tsv"

  : > "$mod_meta"
  for entry in META-INF/neoforge.mods.toml META-INF/mods.toml fabric.mod.json quilt.mod.json; do
    if jar tf "$jar_file" | grep -qx "$entry"; then
      {
        echo "===== $entry ====="
        unzip -p "$jar_file" "$entry" 2>/dev/null || true
        echo
      } >> "$mod_meta"
    fi
  done

  awk '
    /^\[\[mods\]\]/ { in_mod = 1; next }
    /^\[\[/ { in_mod = 0 }
    in_mod && /^[[:space:]]*modId[[:space:]]*=/ {
      split($0, parts, "\"")
      print parts[2]
    }
  ' "$mod_meta" 2>/dev/null \
    | sort -u > "$mod_ids" || true

  {
    echo "# Mod Inspection: ${INSPECT_NAME:-$(basename "$jar_file")}"
    echo
    echo "| Field | Value |"
    echo "| --- | --- |"
    echo "| Source | \`$INSPECT_SOURCE\` |"
    echo "| Jar | \`$jar_file\` |"
    echo "| Pack side | ${INSPECT_SIDE:-unknown} |"
    if [ -s "$mod_ids" ]; then
      echo "| Detected mod ids | $(paste -sd, "$mod_ids" | sed 's/,/, /g') |"
    else
      echo "| Detected mod ids | unknown |"
    fi
    echo
    echo "## Keybindings"
    echo
    if [ -s "$key_tsv" ]; then
      echo "| Translation key | Label | Detected default | Suggested Default Options line |"
      echo "| --- | --- | --- | --- |"
      while IFS=$'\t' read -r key label; do
        default_code="$(detect_default_key_code "$javap_file" "$key")"
        if [ -n "$default_code" ]; then
          default_key="$(glfw_key_name "$default_code")"
        else
          default_key="unknown"
        fi
        if [ "$default_key" = "unknown" ] || ! printf "%s\n" "$default_key" | grep -q '^key\.keyboard\.'; then
          suggested="key_${key}:key.keyboard.unknown:"
        else
          suggested="key_${key}:${default_key}:"
        fi
        escaped_label="$(md_escape "$label")"
        echo "| \`$key\` | $escaped_label | \`$default_key\` | \`$suggested\` |"
      done < "$key_tsv"
    else
      echo "_No keybinding translation keys were found in en_us language files._"
    fi
    echo
    echo "## Config Candidates"
    echo
    if [ -s "$config_tsv" ]; then
      echo "| Candidate | Evidence | Suggested repo path | Repo status |"
      echo "| --- | --- | --- | --- |"
      while IFS=$'\t' read -r candidate evidence owner_path status; do
        echo "| \`$candidate\` | $(md_escape "$evidence") | \`$owner_path\` | $status |"
      done < "$config_tsv"
    else
      echo "_No obvious config file candidates were found._"
    fi
    echo
    echo "## Metadata Files"
    echo
    if [ -s "$mod_meta" ]; then
      echo "Mod loader metadata was found in the jar. Use the downloaded report files under \`$work_dir\` for full raw output."
    else
      echo "_No standard loader metadata file was found._"
    fi
    echo
    echo "## Notes"
    echo
    echo "- Static inspection is heuristic. Confirm important client controls in a real launcher instance when needed."
    echo "- The report does not edit \`config/defaultoptions/keybindings.txt\` or copy config files."
  } > "$report"
}

cmd_inspect_mod() {
  local mod_ref="${MOD:-}"
  local safe_name
  local work_dir
  local report
  local key_count
  local config_count

  require_command curl
  require_command jq
  require_command jar
  require_command unzip

  if [ -z "$mod_ref" ]; then
    echo "ERROR: INSPECT=mod requires MOD=/path/to/mod.pw.toml, a jar path, a Modrinth slug, or a Modrinth URL"
    exit 1
  fi

  resolve_mod_source "$mod_ref"

  safe_name="$(sanitize_name "${INSPECT_NAME:-$(basename "$INSPECT_JAR" .jar)}")"
  work_dir="$REPORT_DIR/mod-$safe_name-files"
  report="$REPORT_DIR/mod-$safe_name.md"
  safe_rm_rf "$work_dir"
  mkdir -p "$work_dir" "$REPORT_DIR"

  write_mod_report "$report" "$INSPECT_JAR" "$work_dir"

  key_count="$(awk -F'\t' '$1 ~ /^key\./ && $1 !~ /^key\.categories\./ && $1 !~ /^key\.category\./ { count++ } END { print count + 0 }' "$work_dir/lang.tsv")"
  config_count="$(wc -l < "$work_dir/configs.tsv" | tr -d ' ')"

  echo "==> Mod inspection report:"
  echo "    $report"
  echo "==> Found $key_count keybinding translation keys"
  echo "==> Found $config_count config candidates"
}

write_instance_scan_report() {
  local instance_dir="$1"
  local report="$2"
  local title="$3"
  local mod_count=0
  local config_count=0
  local defaultconfig_count=0
  local datapack_count=0
  local rel

  if [ -d "$instance_dir/mods" ]; then
    mod_count="$(find "$instance_dir/mods" -type f -name '*.jar' | wc -l)"
  fi
  if [ -d "$instance_dir/config" ]; then
    config_count="$(find "$instance_dir/config" -type f | wc -l)"
  fi
  if [ -d "$instance_dir/defaultconfigs" ]; then
    defaultconfig_count="$(find "$instance_dir/defaultconfigs" -type f | wc -l)"
  fi
  if [ -d "$instance_dir/config/paxi/datapacks" ]; then
    datapack_count="$(find "$instance_dir/config/paxi/datapacks" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  fi

  {
    echo "# $title"
    echo
    echo "| Field | Value |"
    echo "| --- | --- |"
    echo "| Minecraft folder | \`$instance_dir\` |"
    echo "| Mod jars | $mod_count |"
    echo "| Config files | $config_count |"
    echo "| Default config files | $defaultconfig_count |"
    echo "| Paxi datapacks | $datapack_count |"
    echo
    echo "## Expected Pack Paths"
    echo
    echo "| Path | Status |"
    echo "| --- | --- |"
    for rel in mods defaultconfigs config/defaultoptions/keybindings.txt config/paxi/datapacks; do
      if [ -e "$instance_dir/$rel" ]; then
        echo "| \`$rel\` | present |"
      else
        echo "| \`$rel\` | missing |"
      fi
    done
    echo
    echo "## Default Options Key Defaults"
    echo
    if [ -f "$instance_dir/config/defaultoptions/keybindings.txt" ]; then
      echo "\`config/defaultoptions/keybindings.txt\` exists with $(wc -l < "$instance_dir/config/defaultoptions/keybindings.txt" | tr -d ' ') lines."
    else
      echo "_No Default Options keybinding file found._"
    fi
    echo
    echo "## Config Files"
    echo
    if [ -d "$instance_dir/config" ]; then
      find "$instance_dir/config" -type f | sed "s#^$instance_dir/##" | sort | sed 's#^#- `#; s#$#`#' | sed -n '1,200p'
    else
      echo "_No config directory found._"
    fi
    echo
    echo "## Defaultconfigs"
    echo
    if [ -d "$instance_dir/defaultconfigs" ]; then
      find "$instance_dir/defaultconfigs" -type f | sed "s#^$instance_dir/##" | sort | sed 's#^#- `#; s#$#`#' | sed -n '1,200p'
    else
      echo "_No defaultconfigs directory found._"
    fi
    echo
    echo "## Paxi Datapacks"
    echo
    if [ -d "$instance_dir/config/paxi/datapacks" ]; then
      find "$instance_dir/config/paxi/datapacks" -mindepth 1 -maxdepth 1 -type d | sed "s#^$instance_dir/##" | sort | sed 's#^#- `#; s#$#`#'
    else
      echo "_No Paxi datapack directory found._"
    fi
    echo
    echo "## Mod Jars"
    echo
    if [ -d "$instance_dir/mods" ]; then
      find "$instance_dir/mods" -type f -name '*.jar' -printf '%f\n' | sort | sed 's#^#- `mods/#; s#$#`#' | sed -n '1,240p'
    else
      echo "_No mods directory found._"
    fi
  } > "$report"
}

cmd_inspect_instance() {
  local instance_dir="${INSTANCE_MC_DIR:-}"
  local report="$REPORT_DIR/instance.md"

  if [ -z "$instance_dir" ]; then
    echo "ERROR: INSPECT=instance requires INSTANCE_MC_DIR=/path/to/instance/minecraft"
    exit 1
  fi

  if [ ! -d "$instance_dir" ]; then
    echo "ERROR: instance Minecraft folder does not exist: $instance_dir"
    exit 1
  fi

  mkdir -p "$REPORT_DIR"
  write_instance_scan_report "$instance_dir" "$report" "Launcher Instance Inspection"

  echo "==> Instance inspection report:"
  echo "    $report"
}

cmd_inspect_pack() {
  local client_dir="$REPORT_DIR/pack-client"
  local report="$REPORT_DIR/pack.md"

  mkdir -p "$REPORT_DIR"
  safe_rm_rf "$client_dir"

  echo "==> Materializing Packwiz client into:"
  echo "    $client_dir"
  echo "==> Pack URL:"
  echo "    $PACK_URL"

  install_packwiz_client "$client_dir" "$PACK_URL"
  write_instance_scan_report "$client_dir" "$report" "Pack Materialization Inspection"

  echo "==> Pack inspection report:"
  echo "    $report"
}

wait_for_http() {
  local url="$1"
  local attempt

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fs "$url" >/dev/null; then
      return 0
    fi
    sleep 1
  done

  curl -fsS "$url" >/dev/null
}

write_server_generated_report() {
  local server_dir="$1"
  local report="$2"
  local status="$3"
  local world_name
  local world_dir

  world_name="$(sed -n 's/^level-name=//p' "$server_dir/server.properties" 2>/dev/null | tail -n 1)"
  world_name="${world_name:-world}"
  world_dir="$server_dir/$world_name"

  {
    echo "# Generated Server Config Inspection"
    echo
    echo "| Field | Value |"
    echo "| --- | --- |"
    echo "| Runtime folder | \`$server_dir\` |"
    echo "| Start command exit status | \`$status\` |"
    echo "| World folder | \`$world_name\` |"
    echo
    echo "## Root Config"
    echo
    if [ -d "$server_dir/config" ]; then
      find "$server_dir/config" -type f | sed "s#^$server_dir/##" | sort | sed 's#^#- `#; s#$#`#' | sed -n '1,240p'
    else
      echo "_No root config directory found._"
    fi
    echo
    echo "## Defaultconfigs"
    echo
    if [ -d "$server_dir/defaultconfigs" ]; then
      find "$server_dir/defaultconfigs" -type f | sed "s#^$server_dir/##" | sort | sed 's#^#- `#; s#$#`#' | sed -n '1,240p'
    else
      echo "_No defaultconfigs directory found._"
    fi
    echo
    echo "## World Serverconfig"
    echo
    if [ -d "$world_dir/serverconfig" ]; then
      find "$world_dir/serverconfig" -type f | sed "s#^$server_dir/##" | sort | sed 's#^#- `#; s#$#`#' | sed -n '1,240p'
    else
      echo "_No world serverconfig directory found. The server may not have reached world creation before it stopped._"
    fi
    echo
    echo "## Notes"
    echo
    echo "- Runtime files are under ignored \`dist/inspect/\`; nothing was copied into the live server."
    echo "- This task fails unless NeoForge reaches completed startup and exits cleanly."
  } > "$report"
}

verify_generated_server_startup() {
  local server_dir="$1"
  local start_status="$2"
  local log_file="$server_dir/logs/latest.log"
  local kubejs_log="$server_dir/logs/kubejs/server.log"
  local bad_pattern

  if [ "$start_status" -ne 0 ]; then
    echo "ERROR: temporary server exited with status $start_status"
    return 1
  fi

  if [ ! -f "$log_file" ] || ! grep -q 'Done (' "$log_file"; then
    echo "ERROR: temporary server did not reach completed startup"
    return 1
  fi

  for bad_pattern in \
    'Parsing error loading recipe' \
    'Failed to load function' \
    "Couldn't load advancements" \
    "Couldn't load tag" \
    "Couldn't parse element" \
    'Could not detect dedicated-server mode' \
    'Mobs should be added to biomes under the same mob category'; do
    if grep -Fq "$bad_pattern" "$log_file"; then
      echo "ERROR: temporary server log contains: $bad_pattern"
      grep -F "$bad_pattern" "$log_file" | sed -n '1,5p'
      return 1
    fi
  done

  if [ -f "$kubejs_log" ] && grep -Eq 'Loaded [0-9]+/[0-9]+ KubeJS server scripts .* with [1-9][0-9]* errors' "$kubejs_log"; then
    echo "ERROR: KubeJS reported server-script errors"
    grep -E 'Loaded [0-9]+/[0-9]+ KubeJS server scripts' "$kubejs_log" | tail -n 3
    return 1
  fi

  echo "==> Verified completed server startup and clean custom data loading"
}

verify_upstream_overrides() {
  local server_dir="$1"
  local data_root="$REPO_DIR/config/paxi/datapacks/minecraft_convenience_recipes/data"
  local file
  local relative
  local namespace
  local jar_pattern
  local jar_file
  local upstream_file
  local entity_blood_file="$data_root/vampirism/data_maps/entity_type/entity_blood.json"
  local vampirism_jar
  local werewolves_jar
  local tag_name
  local tag_file
  local upstream_tag_values
  local custom_tag_values
  local checked=0

  require_command jq
  require_command unzip

  upstream_file="$(mktemp)"
  vampirism_jar="$(find "$server_dir/mods" -maxdepth 1 -type f -name 'Vampirism-*.jar' -print -quit)"

  if [ -z "$vampirism_jar" ] || ! unzip -p "$vampirism_jar" \
    data/vampirism/data_maps/entity_type/entity_blood.json > "$upstream_file"; then
    echo "ERROR: upstream Vampirism entity blood data map is missing"
    rm -f "$upstream_file"
    return 1
  fi

  if ! jq -ne \
    --slurpfile upstream "$upstream_file" \
    --slurpfile custom "$entity_blood_file" \
    '$upstream[0].values as $base | $custom[0].values as $ours | all($base | keys[]; . as $key | $base[$key] == $ours[$key])' \
    >/dev/null; then
    echo "ERROR: duplicated upstream entries in entity_blood.json have drifted from Vampirism"
    rm -f "$upstream_file"
    return 1
  fi
  checked=$((checked + 1))

  for tag_name in undead powder_snow_walkable_mobs; do
    tag_file="$data_root/minecraft/tags/entity_type/$tag_name.json"
    upstream_tag_values="$(mktemp)"
    custom_tag_values="$(mktemp)"
    for jar_file in "$server_dir"/mods/*.jar; do
      unzip -p "$jar_file" "data/minecraft/tags/entity_type/$tag_name.json" 2>/dev/null \
        | jq -r '.values[] | if type == "string" then . else .id end' 2>/dev/null || true
    done | sort -u > "$upstream_tag_values"
    jq -r '.values[] | if type == "string" then . else .id end' "$tag_file" | sort -u > "$custom_tag_values"
    if [ -n "$(comm -23 "$upstream_tag_values" "$custom_tag_values")" ]; then
      echo "ERROR: minecraft:$tag_name override is missing entries contributed by installed mods"
      comm -23 "$upstream_tag_values" "$custom_tag_values" | sed -n '1,20p'
      rm -f "$upstream_file" "$upstream_tag_values" "$custom_tag_values"
      return 1
    fi
    rm -f "$upstream_tag_values" "$custom_tag_values"
    checked=$((checked + 1))
  done

  for file in "$data_root"/vampirism/vampirism/tasks/*.json; do
    relative="${file#"$data_root/"}"
    jar_file="$vampirism_jar"
    if [ -z "$jar_file" ] || ! unzip -p "$jar_file" "data/$relative" > "$upstream_file"; then
      echo "ERROR: upstream task is missing from the installed Vampirism jar: $relative"
      rm -f "$upstream_file"
      return 1
    fi

    if ! diff -q \
      <(jq -S 'del(.requirements)' "$file") \
      <(jq -S 'del(.requirements)' "$upstream_file") >/dev/null; then
      echo "ERROR: custom task override has drifted beyond its requirements: $relative"
      rm -f "$upstream_file"
      return 1
    fi
    checked=$((checked + 1))
  done

  while IFS= read -r file; do
    relative="${file#"$data_root/"}"
    namespace="${relative%%/*}"
    case "$namespace" in
      guardvillagers) jar_pattern='guardvillagers-*.jar' ;;
      vampirism) jar_pattern='Vampirism-*.jar' ;;
      benssharks) jar_pattern='benssharks-*.jar' ;;
      irons_spellbooks) jar_pattern='irons_spellbooks-*.jar' ;;
      wind_spellbooks) jar_pattern='wind_spellbooks-*.jar' ;;
      *) continue ;;
    esac

    jar_file="$(find "$server_dir/mods" -maxdepth 1 -type f -name "$jar_pattern" -print -quit)"
    if [ -z "$jar_file" ] || ! unzip -p "$jar_file" "data/$relative" > "$upstream_file"; then
      echo "ERROR: upstream loot table is missing from its installed mod jar: $relative"
      rm -f "$upstream_file"
      return 1
    fi

    if ! diff -q \
      <(jq -S 'del(.pools[-1]) | if .pools == [] then del(.pools) else . end' "$file") \
      <(jq -S 'if .pools == [] then del(.pools) else . end' "$upstream_file") >/dev/null; then
      echo "ERROR: custom loot override has drifted before its appended corpse pool: $relative"
      rm -f "$upstream_file"
      return 1
    fi
    checked=$((checked + 1))
  done < <(find "$data_root" -path '*/loot_table/entities/*.json' ! -path '*/minecraft/*' | sort)

  werewolves_jar="$(find "$server_dir/mods" -maxdepth 1 -type f -name 'Werewolves-*.jar' -print -quit)"
  if [ -z "$werewolves_jar" ] || ! unzip -p "$werewolves_jar" \
    data/werewolves/worldgen/biome/werewolf_heaven.json > "$upstream_file"; then
    echo "ERROR: upstream Werewolves heaven biome is missing"
    rm -f "$upstream_file"
    return 1
  fi
  if ! diff -q \
    <(jq -S . "$data_root/werewolves/worldgen/biome/werewolf_heaven.json") \
    <(jq -S '(.spawners["werewolves:werewolf"] = .spawners.monster) | (.spawners.monster = [])' "$upstream_file") >/dev/null; then
    echo "ERROR: Werewolves heaven biome override has drifted beyond spawn-category repair"
    rm -f "$upstream_file"
    return 1
  fi
  checked=$((checked + 1))

  for relative in \
    werewolves/neoforge/biome_modifier/spawn/human_werewolf_spawns.json \
    werewolves/neoforge/biome_modifier/spawn/werewolf_spawns.json; do
    if ! unzip -p "$werewolves_jar" "data/$relative" > "$upstream_file"; then
      echo "ERROR: upstream Werewolves spawn modifier is missing: $relative"
      rm -f "$upstream_file"
      return 1
    fi
    if ! diff -q \
      <(jq -S 'walk(if type == "object" and has("category") then del(.category) else . end)' "$data_root/$relative") \
      <(jq -S 'walk(if type == "object" and has("category") then del(.category) else . end)' "$upstream_file") >/dev/null; then
      echo "ERROR: Werewolves spawn override has drifted beyond category repair: $relative"
      rm -f "$upstream_file"
      return 1
    fi
    checked=$((checked + 1))
  done

  rm -f "$upstream_file"
  echo "==> Verified $checked custom data overrides against installed upstream jars"
}

set_inspection_server_port() {
  local server_dir="$1"
  local server_properties="$server_dir/server.properties"

  if [ ! -f "$server_properties" ]; then
    echo "WARN: server.properties missing; cannot set temporary inspection port"
    return 0
  fi

  if grep -q '^server-port=' "$server_properties"; then
    sed -i 's/^server-port=.*/server-port=0/' "$server_properties"
  else
    printf "\nserver-port=0\n" >> "$server_properties"
  fi

  echo "==> Temporary inspection server port: 0 (auto-select free port)"
}

cmd_inspect_server_generated() {
  local root="$REPORT_DIR/server-generated"
  local site_dir="$root/site/stable"
  local site_root="$root/site"
  local server_dir="$root/runtime"
  local report="$REPORT_DIR/server-generated.md"
  local port="${INSPECT_SITE_PORT:-8091}"
  local local_pack_url="http://127.0.0.1:${port}/stable/pack.toml"
  local server_pid=""
  local start_status=0

  require_command python3
  require_command timeout
  require_java21

  mkdir -p "$REPORT_DIR"
  safe_rm_rf "$root"
  mkdir -p "$root"

  echo "==> Building temporary Packwiz site for generated server inspection"
  (
    SITE_DIR="$site_dir" cmd_site
  )

  python3 -m http.server "$port" --directory "$site_root" >/tmp/mc-fantasy-pack-inspect-http.log 2>&1 &
  server_pid="$!"
  trap 'if [ -n "${server_pid:-}" ]; then kill "$server_pid" >/dev/null 2>&1 || true; fi' EXIT
  wait_for_http "$local_pack_url"

  echo "==> Creating temporary server runtime:"
  echo "    $server_dir"
  SERVER_DIR="$server_dir" PACK_URL="$local_pack_url" JAVA21="$JAVA21" ACCEPT_EULA=true "$REPO_DIR/scripts/server.sh" setup
  set_inspection_server_port "$server_dir"

  echo "==> Starting temporary server to generate configs"
  set +e
  (
    sleep "${SERVER_GENERATED_STOP_AFTER:-90}"
    printf "stop\n"
  ) | timeout "${SERVER_GENERATED_TIMEOUT:-600}" env SERVER_DIR="$server_dir" PACK_URL="$local_pack_url" JAVA21="$JAVA21" "$REPO_DIR/scripts/server.sh" start
  start_status="$?"
  set -e

  write_server_generated_report "$server_dir" "$report" "$start_status"
  verify_generated_server_startup "$server_dir" "$start_status"
  verify_upstream_overrides "$server_dir"

  echo "==> Generated server config report:"
  echo "    $report"
  echo "==> Temporary runtime retained:"
  echo "    $server_dir"

  trap - EXIT
  if [ -n "$server_pid" ]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}

cmd_inspect() {
  case "${INSPECT:-}" in
    mod)
      cmd_inspect_mod
      ;;
    instance)
      cmd_inspect_instance
      ;;
    pack)
      cmd_inspect_pack
      ;;
    server-generated)
      cmd_inspect_server_generated
      ;;
    "")
      echo "ERROR: inspect requires INSPECT=mod, instance, pack, or server-generated"
      usage
      exit 1
      ;;
    *)
      echo "ERROR: unknown INSPECT mode: $INSPECT"
      usage
      exit 1
      ;;
  esac
}

case "$ACTION" in
  site)
    cmd_site
    ;;
  export-client)
    cmd_export_client
    ;;
  smoke-update)
    cmd_smoke_update
    ;;
  inspect)
    cmd_inspect
    ;;
  client-test)
    cmd_client_test
    ;;
  build-auth-tools)
    cmd_build_auth_tools
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "ERROR: unknown action: $ACTION"
    usage
    exit 1
    ;;
esac
