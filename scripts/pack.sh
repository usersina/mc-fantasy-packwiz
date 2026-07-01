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
REPORT_DIR="${REPORT_DIR:-$REPO_DIR/dist/inspect}"
ACTION="${1:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <site|export-client|smoke-update|inspect>

Actions:
  site           Refresh Packwiz and build the hosted stable Packwiz site.
  export-client  Refresh Packwiz and export the stable Prism/Freesm .mrpack.
  smoke-update   Install the client pack into a temp folder and verify basics.
  inspect        Inspect mods, materialized packs, launcher instances, or generated server configs.

Inspect examples:
  INSPECT=mod MOD=mods/beltborne-lanterns.pw.toml $(basename "$0") inspect
  INSPECT=instance INSTANCE_MC_DIR=/path/to/instance/minecraft $(basename "$0") inspect
  INSPECT=pack PACK_URL=http://127.0.0.1:8081/stable/pack.toml $(basename "$0") inspect
  INSPECT=server-generated $(basename "$0") inspect
EOF
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command_name"
    exit 1
  fi
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

install_packwiz_client() {
  local target_dir="$1"
  local pack_url="$2"

  require_java21
  download_if_missing "$PACKWIZ_INSTALLER_CACHE" "$PACKWIZ_INSTALLER_URL"
  mkdir -p "$target_dir"

  (
    cd "$target_dir"
    "$JAVA21" -jar "$PACKWIZ_INSTALLER_CACHE" -g -s client "$pack_url"
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
    local status="$1"

    if [ "$status" -eq 0 ] && [ "$created_smoke_dir" = "true" ] && [ "${KEEP_SMOKE_DIR:-false}" != "true" ]; then
      rm -rf "$smoke_dir"
      return 0
    fi

    echo "==> Smoke client folder retained:"
    echo "    $smoke_dir"
  }
  trap 'status=$?; cleanup_smoke "$status"' EXIT

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
  cleanup_smoke 0
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

  if strings "$jar_file" | grep -q 'Toml4jConfigSerializer'; then
    printf "toml"
  elif strings "$jar_file" | grep -q 'JanksonConfigSerializer'; then
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
    strings "$jar_file" \
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
    if curl -fsS "$url" >/dev/null; then
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
    echo "- If the exit status is non-zero because of a timeout, inspect the generated files and rerun with a larger \`SERVER_GENERATED_TIMEOUT\`."
  } > "$report"
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
  trap 'if [ -n "$server_pid" ]; then kill "$server_pid" >/dev/null 2>&1 || true; fi' EXIT
  wait_for_http "$local_pack_url"

  echo "==> Creating temporary server runtime:"
  echo "    $server_dir"
  SERVER_DIR="$server_dir" PACK_URL="$local_pack_url" JAVA21="$JAVA21" ACCEPT_EULA=true "$REPO_DIR/scripts/server.sh" setup

  echo "==> Starting temporary server to generate configs"
  set +e
  (
    sleep "${SERVER_GENERATED_STOP_AFTER:-90}"
    printf "stop\n"
  ) | timeout "${SERVER_GENERATED_TIMEOUT:-240}" env SERVER_DIR="$server_dir" PACK_URL="$local_pack_url" JAVA21="$JAVA21" "$REPO_DIR/scripts/server.sh" start
  start_status="$?"
  set -e

  write_server_generated_report "$server_dir" "$report" "$start_status"

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
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "ERROR: unknown action: $ACTION"
    usage
    exit 1
    ;;
esac
