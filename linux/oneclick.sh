#!/usr/bin/env bash
# OneClick Kit - runs the maintenance steps in order and prints a summary.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
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

banner "OneClick Kit"

printf '\n%s\n' "  This will:"
printf '%s\n' "    1. Close Chrome, Chromium, Brave, Edge and Firefox and clear their cache"
printf '%s\n' "       (history, cookies, passwords and logins are kept)"
printf '%s\n' "    2. Clean package caches, old logs, old temp files, crash reports, thumbnails and Trash"
printf '%s\n' "    3. Clear developer package caches: npm, pnpm, yarn, bun and pip"
printf '%s\n' "    4. Install system, Flatpak, Snap and firmware updates"

countdown 10 "Save your work in open browsers first."

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

TOTAL=4
NAMES=("Browser cache cleanup" "System junk cleanup" "Developer cache cleanup" "System updates")
PATHS=("cleanup/clean_browser_cache.sh" "cleanup/clean_system_junk.sh" "cleanup/clean_dev_caches.sh" "update/update_system.sh")
CODES=()
DURS=()

child_args=(--auto)
if [[ $DRY_RUN -eq 1 ]]; then
  child_args+=(--dry-run)
fi

for ((i = 0; i < TOTAL; i++)); do
  printf '\n[%s/%s] %s\n' "$((i + 1))" "$TOTAL" "${NAMES[i]}"
  printf '%s\n' "------------------------------------------------------------"
  start=$SECONDS
  bash "$SCRIPT_DIR/${PATHS[i]}" "${child_args[@]}"
  CODES[i]=$?
  DURS[i]=$((SECONDS - start))
  if [[ ${CODES[i]} -ne 0 ]]; then RESULT=1; fi
done

printf '\n%s\n' "============================================================"
printf '  %s\n' "Summary"
printf '%s\n' "============================================================"
for ((i = 0; i < TOTAL; i++)); do
  d=${DURS[i]}
  dur="$((d / 60))m $(printf '%02d' $((d % 60)))s"
  if [[ ${CODES[i]} -eq 0 ]]; then
    printf '  %s%-11s%s%-36s %s\n' "$GREEN" "[OK]" "$RESET" "${NAMES[i]}" "$dur"
  else
    printf '  %s%-11s%s%-36s %s   exit code %s\n' "$YELLOW" "[WARNING]" "$RESET" "${NAMES[i]}" "$dur" "${CODES[i]}"
  fi
done

if [[ $DRY_RUN -eq 0 ]]; then
  printf '\n'
  if reboot_needed; then
    info "A restart is needed to finish installing updates."
    if [[ $AUTO -eq 0 && -t 0 ]]; then
      read -rp "Restart now? [y/N] " ans
      case "$ans" in
        y|Y) sudo systemctl reboot ;;
      esac
    fi
  else
    info "No restart needed."
  fi
else
  printf '\n'
  info "Restart check skipped in dry run."
fi

pause_end
exit "$RESULT"
