#!/usr/bin/env bash
# First Install - one click for a fresh Linux machine: your apps, then the shared dev cache.
# Runs as the user; system installs ask for sudo once at the start.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"
refuse_sudo

GREEN=""
YELLOW=""
RESET=""
if [[ -t 1 ]]; then
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RESET=$'\033[0m'
fi

banner "First Install"

printf '\n%s\n' "  This will:"
printf '%s\n' "    1. Install your apps from the lists saved by save_my_apps.sh (system, Flatpak, Snap)"
printf '%s\n' "    2. Set up one shared developer cache folder for all projects"

KEEPALIVE_PID=""
if [[ $DRY_RUN -eq 0 ]]; then
  if ! sudo -v; then
    printf '%s\n' "sudo password was not accepted. Nothing was changed."
    exit 1
  fi
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
  KEEPALIVE_PID=$!
  trap 'kill "$KEEPALIVE_PID" 2>/dev/null' EXIT
fi

child_args=(--auto)
if [[ $DRY_RUN -eq 1 ]]; then
  child_args+=(--dry-run)
fi

APPS_STATE="skipped"
APPS_CODE=0
CACHE_STATE="ok"
CACHE_CODE=0

step 1 2 "Apps"
has_lists=0
for f in "$SCRIPT_DIR"/packages-*.txt "$SCRIPT_DIR/flatpak.txt" "$SCRIPT_DIR/snap.txt"; do
  if [[ -f "$f" ]]; then has_lists=1; fi
done
if [[ $has_lists -eq 1 ]]; then
  bash "$SCRIPT_DIR/install_apps.sh" "${child_args[@]}"
  APPS_CODE=$?
  if [[ $APPS_CODE -eq 0 ]]; then APPS_STATE="ok"; else APPS_STATE="warn"; RESULT=1; fi
else
  info "No app lists found - app install skipped. Run save_my_apps.sh on your old machine to create them."
fi

step 2 2 "Shared cache"
bash "$SCRIPT_DIR/setup_shared_cache.sh" "${child_args[@]}"
CACHE_CODE=$?
if [[ $CACHE_CODE -eq 0 ]]; then CACHE_STATE="ok"; else CACHE_STATE="warn"; RESULT=1; fi

summary_line() {
  local label="$1" state="$2"
  case "$state" in
    ok) printf '  %s%-14s%s %s\n' "$GREEN" "$label:" "$RESET" "OK" ;;
    skipped) printf '  %s%-14s%s %s\n' "$YELLOW" "$label:" "$RESET" "skipped - no app lists" ;;
    *) printf '  %s%-14s%s %s\n' "$YELLOW" "$label:" "$RESET" "finished with warnings" ;;
  esac
}

printf '\n%s\n' "============================================================"
printf '  %s\n' "Summary"
printf '%s\n' "============================================================"
summary_line "Apps" "$APPS_STATE"
summary_line "Shared cache" "$CACHE_STATE"

printf '\n%s\n' "First install finished. Restart so every app and setting is picked up."
pause_end
exit "$RESULT"
