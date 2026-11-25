#!/usr/bin/env bash
# One safe entry point. No action is applied by default.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-all}"
apply=0
if [[ "$mode" == --help || "$mode" == -h || "$mode" == --dry-run ]]; then
  [[ $# -eq 1 ]] || exit 2
  mode=all
fi
if [[ $# -gt 2 || ( $# -eq 2 && "${2:-}" != --apply && "${2:-}" != --dry-run ) ]]; then
  printf '%s\n' 'Usage: oneclick.sh [all|install|update|clean|cache] [--apply|--dry-run]'; exit 2
fi
case "$mode" in all|install|update|clean|cache) ;; *) printf '%s\n' 'Unknown operation'; exit 2 ;; esac
[[ "${2:-}" == --apply ]] && apply=1
printf '%s\n' 'OneClick Kit' "Operation: $mode" 'Available: all, install, update, clean, cache.'
if [[ "$mode" == all || "$mode" == install ]]; then
  printf '%s\n' 'Install: approved development profile only; unsupported tools are reported.'
  if command -v node >/dev/null; then node "$HERE/../tools/install-development.mjs" --all || exit $?; else printf '%s\n' 'Node.js is needed first: https://nodejs.org/en/download'; fi
fi
if [[ "$mode" == all || "$mode" == update ]]; then printf '%s\n' 'Update: supported OS, managed applications and firmware; restart requires confirmation.'; fi
if [[ "$mode" == all || "$mode" == cache ]]; then printf '%s\n' 'Cache: configure shared downloads and isolated project targets.'; fi
if [[ "$mode" == all || "$mode" == clean ]]; then
  printf '%s\n' 'Clean: only reviewed idle project dependencies and build outputs; shared downloads are preserved.'
  if command -v node >/dev/null; then node "$HERE/../tools/devcache.mjs" clean-idle || exit $?; fi
fi
if [[ $apply -eq 0 ]]; then
  printf '%s\n' 'Preview only. To apply, rerun with an operation followed by --apply. Nothing was changed.'
  exit 0
fi
if [[ ! -t 0 ]]; then printf '%s\n' 'Interactive confirmation required. Nothing was changed.'; exit 1; fi
read -rp "Type APPLY to run $mode: " answer
if [[ "$answer" != APPLY ]]; then printf '%s\n' 'Cancelled.'; exit 0; fi
# On a fresh machine, bootstrap only the approved Node.js runtime using the detected trusted package manager.
if [[ "$mode" != update ]] && ! command -v node >/dev/null; then
  if [[ "$mode" != install && "$mode" != all ]]; then printf '%s\n' 'Install Node.js first using install --apply.'; exit 1; fi
  if command -v apt-get >/dev/null; then sudo apt-get install nodejs npm || exit $?
  elif command -v dnf >/dev/null; then sudo dnf install nodejs npm || exit $?
  elif command -v pacman >/dev/null; then sudo pacman -S --needed nodejs npm || exit $?
  elif command -v zypper >/dev/null; then sudo zypper install nodejs || exit $?
  else printf '%s\n' 'Install Node.js from https://nodejs.org/en/download and rerun.'; exit 1; fi
  command -v node >/dev/null || exit 1
fi
if [[ "$mode" == all || "$mode" == install ]]; then bash "$HERE/install/first_install.sh" --apply --all || exit $?; fi
if [[ "$mode" == cache ]]; then bash "$HERE/install/setup_shared_cache.sh" || exit $?; fi
if [[ "$mode" == all || "$mode" == update ]]; then bash "$HERE/update/update_system.sh" --auto || exit $?; fi
if [[ "$mode" == all || "$mode" == clean ]]; then node "$HERE/../tools/devcache.mjs" clean-idle --apply || exit $?; fi
printf '%s\n' 'Finished. Review any manual tool steps and restart if needed.'
