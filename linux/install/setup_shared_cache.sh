#!/usr/bin/env bash
# Shared Cache Setup - one shared, regenerable dev cache folder for all projects (user level, no sudo).
# Usage: setup_shared_cache.sh [folder] [--auto] [--dry-run]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

DEFAULT_FOLDER="$HOME/F-project/shared-cache"
CACHE_NAMES=(pnpm-store cargo-target sccache gradle npm-cache puppeteer)
MARK_START="# >>> OneClick Kit shared cache >>>"
MARK_END="# <<< OneClick Kit shared cache <<<"

# The first argument that does not start with "-" is the folder; the rest go to parse_args.
FOLDER=""
FOLDER_GIVEN=0
PASS_ARGS=()
for arg in "$@"; do
  if [[ $FOLDER_GIVEN -eq 0 && "$arg" != -* ]]; then
    FOLDER="$arg"
    FOLDER_GIVEN=1
  else
    PASS_ARGS+=("$arg")
  fi
done
parse_args ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
refuse_sudo

if [[ $FOLDER_GIVEN -eq 0 ]]; then FOLDER="$DEFAULT_FOLDER"; fi
if [[ -z "$FOLDER" ]]; then
  fail "No cache folder given. Nothing was changed."
  exit 1
fi
if [[ "$FOLDER" != /* ]]; then FOLDER="$PWD/$FOLDER"; fi
while [[ "$FOLDER" == */ && "$FOLDER" != / ]]; do
  FOLDER="${FOLDER%/}"
done
HOME_DIR="${HOME%/}"
if [[ "$FOLDER" == / || "$FOLDER" == "$HOME_DIR" ]]; then
  fail "Refusing to use $FOLDER as the cache folder. Choose a folder inside your home, for example $DEFAULT_FOLDER"
  exit 1
fi
CACHE="$FOLDER"

banner "Shared Cache Setup"

step 1 5 "Location"
info "Folder: $CACHE"
info "Keep it on the same disk as your projects - hard links do not work across disks."

step 2 5 "Folders"
for name in "${CACHE_NAMES[@]}"; do
  if [[ -d "$CACHE/$name" ]]; then
    info "$name exists"
  else
    run mkdir -p "$CACHE/$name" || fail "could not create $CACHE/$name"
  fi
done

step 3 5 "Tools"
SCCACHE_OK=0
if have sccache; then
  info "sccache installed"
  SCCACHE_OK=1
else
  pm="$(detect_pm)"
  case "$pm" in
    apt) as_root apt-get install -y sccache ;;
    dnf) as_root dnf install -y sccache ;;
    pacman) as_root pacman -S --needed --noconfirm sccache ;;
    zypper) as_root zypper --non-interactive install sccache ;;
    *) info "No supported package manager found - sccache not installed." ;;
  esac
  if [[ $DRY_RUN -eq 0 ]]; then
    hash -r
    if have sccache; then
      SCCACHE_OK=1
      info "sccache installed"
    elif [[ "$pm" != none ]]; then
      fail "sccache could not be installed. RUSTC_WRAPPER will not be set."
    fi
  fi
fi

PNPM_PENDING=0
if have pnpm; then
  info "pnpm installed"
elif have npm; then
  run npm install -g pnpm || as_root npm install -g pnpm
  if [[ $DRY_RUN -eq 1 ]]; then
    PNPM_PENDING=1
  else
    hash -r
    if have pnpm; then
      info "pnpm installed"
    else
      fail "pnpm could not be installed"
    fi
  fi
else
  info "npm not found - install Node.js first, then run this again"
  fail "pnpm could not be installed"
fi

step 4 5 "pnpm and npm settings"
if have pnpm || [[ $PNPM_PENDING -eq 1 ]]; then
  run pnpm config set store-dir "$CACHE/pnpm-store" --global || fail "could not set pnpm store-dir"
  run pnpm config set package-import-method hardlink --global || fail "could not set pnpm package-import-method"
else
  fail "pnpm not found, pnpm settings skipped"
fi
if have npm; then
  run npm config set cache "$CACHE/npm-cache" || fail "could not set npm cache folder"
else
  info "npm not found, skipped"
fi

step 5 5 "Environment variables"
block="$MARK_START"$'\n'
block+="export CARGO_TARGET_DIR=\"$CACHE/cargo-target\""$'\n'
block+="export CARGO_INCREMENTAL=0"$'\n'
block+="export SCCACHE_DIR=\"$CACHE/sccache\""$'\n'
block+="export SCCACHE_CACHE_SIZE=5G"$'\n'
block+="export GRADLE_USER_HOME=\"$CACHE/gradle\""$'\n'
block+="export PUPPETEER_CACHE_DIR=\"$CACHE/puppeteer\""$'\n'
if [[ $SCCACHE_OK -eq 1 ]]; then
  block+="export RUSTC_WRAPPER=sccache"$'\n'
else
  info "RUSTC_WRAPPER not set - Rust builds fail when it points to a missing sccache."
fi
block+="$MARK_END"

if [[ $DRY_RUN -eq 1 ]]; then
  printf '  [dry run] would write this block to ~/.profile:\n'
  printf '%s\n' "$block" | sed 's/^/    /'
else
  profile="$HOME/.profile"
  if ! { touch "$profile" \
    && sed -i '/^# >>> OneClick Kit shared cache >>>$/,/^# <<< OneClick Kit shared cache <<<$/d' "$profile" \
    && sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$profile" \
    && { if [[ -s "$profile" && -n "$(tail -c1 "$profile")" ]]; then printf '\n'; fi; if [[ -s "$profile" ]]; then printf '\n'; fi; printf '%s\n' "$block"; } >> "$profile"; }; then
    fail "could not write $profile"
  else
    info "Wrote the shared cache block to $profile"
  fi
fi

printf '\n%s\n' "Shared cache setup finished. Log out and back in, or run: source ~/.profile - then run pnpm install in each project."
pause_end
exit "$RESULT"
