#!/usr/bin/env bash
# One safe entry point. No action is applied by default.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
AC_TIMER="$HERE/../linux/schedule/auto_clean_timer.sh"
AC_DRY="$HERE/schedule/auto_clean.sh"
KIT_URL='https://github.com/Nexvyn/OneClick-Kit'

# Live auto-clean state. The first status line is "Auto-clean: On" or "Auto-clean: Off".
auto_clean_state() {
  ac_line="$(bash "$AC_TIMER" --status 2>/dev/null | head -n 1)"
  ac_state=Off
  [[ "$ac_line" == "Auto-clean: On" ]] && ac_state=On
  [[ -n "$ac_line" ]] || ac_line="Auto-clean: Off"
  return 0
}

# Menu choice 6: ask, then turn auto-clean on or off.
auto_clean_menu() {
  local ans flag
  if [[ "$ac_state" == On ]]; then
    read -rp 'Turn it off? [y/N] ' ans; flag=--disable
  else
    read -rp 'Turn it on? [y/N] ' ans; flag=--enable
  fi
  case "$ans" in
    y|Y) bash "$AC_TIMER" "$flag"; return $? ;;
    *) printf '%s\n' 'Nothing was changed.'; return 0 ;;
  esac
}

# Self-update: git pull when this is a git checkout, otherwise point to the download page.
self_update_available() {
  [[ -d "$REPO/.git" ]] && command -v git >/dev/null
}

self_update_preview() {
  if self_update_available; then
    printf '%s\n' "Would run: git -C \"$REPO\" pull --ff-only"
  else
    printf '%s\n' "Download the latest from $KIT_URL"
  fi
}

self_update_run() {
  if self_update_available; then
    git -C "$REPO" pull --ff-only
    return $?
  fi
  printf '%s\n' "Download the latest from $KIT_URL"
  return 0
}

# Section 8: delete kit logs older than 30 days. Runs only at the start of an apply run.
prune_kit_logs() {
  local d="$HOME/.local/state/oneclick-kit/logs"
  [[ -d "$d" ]] && find "$d" -type f -mtime +30 -delete 2>/dev/null
  return 0
}

if [[ $# -eq 0 && -t 0 ]]; then
  auto_clean_state
  printf '%s\n' '' 'What do you want to do?' \
    '  1. Install    - choose browsers, then developer tools and shared cache' \
    '  2. Debloat    - remove preinstalled junk apps, ads and tracking' \
    '  3. Update     - system, drivers and apps' \
    '  4. Clean - temp files, Recycle Bin, startup apps, idle project build folders, download caches' \
    '  5. Everything - install, debloat, update and clean' \
    "  6. Auto-clean - turn cleaning every 2 days on or off (now: ${ac_state})" \
    '  U. Update OneClick Kit (download the latest version)' \
    '  Q. Quit'
  read -rp 'Choose 1, 2, 3, 4, 5, 6, U or Q: ' choice
  case "$choice" in
    1) menu_mode=install ;;
    2) menu_mode=debloat ;;
    3) menu_mode=update ;;
    4) menu_mode=clean ;;
    5) menu_mode=all ;;
    6) menu_mode=autoclean ;;
    U|u) menu_mode=self-update ;;
    *) printf '%s\n' 'Nothing was changed.'; exit 0 ;;
  esac
  if [[ "$menu_mode" == autoclean ]]; then
    auto_clean_menu; menu_rc=$?
  elif [[ "$menu_mode" == self-update ]]; then
    self_update_run; menu_rc=$?
  else
    bash "$0" "$menu_mode" --apply; menu_rc=$?
  fi
  read -rp 'Done. Press Enter to close.' _
  exit "$menu_rc"
fi
mode="${1:-all}"
apply=0
if [[ "$mode" == --help || "$mode" == -h || "$mode" == --dry-run ]]; then
  [[ $# -eq 1 ]] || exit 2
  mode=all
fi
if [[ $# -gt 2 || ( $# -eq 2 && "${2:-}" != --apply && "${2:-}" != --dry-run ) ]]; then
  printf '%s\n' 'Usage: oneclick.sh [all|install|debloat|update|clean|cache|autoclean|self-update|startup] [--apply|--dry-run]'; exit 2
fi
case "$mode" in all|install|debloat|update|clean|cache|autoclean|self-update|startup) ;; *) printf '%s\n' 'Unknown operation'; exit 2 ;; esac
[[ "${2:-}" == --apply ]] && apply=1
printf '%s\n' 'OneClick Kit' "Operation: $mode" 'Available: all, install, debloat, update, clean, cache, autoclean, self-update, startup.'
if [[ "$mode" == all || "$mode" == install ]]; then
  printf '%s\n' 'Install: approved development profile only; unsupported tools are reported.' 'Also set up: Git and GitHub SSH setup.'
  if command -v node >/dev/null; then
    node "$HERE/../tools/browsers.mjs" || exit $?
    node "$HERE/../tools/install-development.mjs" --all || exit $?
  else printf '%s\n' 'Node.js is needed first: https://nodejs.org/en/download'; fi
fi
if [[ "$mode" == all || "$mode" == debloat ]]; then
  printf '%s\n' 'Debloat: preinstalled junk apps, ads, promo items, tracking and background services.'
  bash "$HERE/debloat/debloat_linux.sh" --dry-run --auto || exit $?
fi
if [[ "$mode" == all || "$mode" == update ]]; then printf '%s\n' 'Update: supported OS, managed applications and firmware; restart requires confirmation.'; fi
if [[ "$mode" == all || "$mode" == cache ]]; then printf '%s\n' 'Cache: configure shared downloads and isolated project targets.'; fi
if [[ "$mode" == all || "$mode" == clean ]]; then
  printf '%s\n' 'Clean: temp files, journal logs, crash reports, Trash, idle project dependencies and Cargo targets, plus download cache pruning.'
  if command -v node >/dev/null; then node "$HERE/../tools/devcache.mjs" clean-idle || exit $?; fi
  bash "$HERE/cleanup/clean_dev_caches.sh" --auto --dry-run || exit $?
  bash "$HERE/cleanup/clean_system_junk.sh" --auto --dry-run || exit $?
  bash "$HERE/cleanup/startup_apps.sh" --dry-run || exit $?
fi
if [[ "$mode" == startup ]]; then
  printf '%s\n' 'Startup apps: turn off new startup programs; protected and kept items are skipped.'
  bash "$HERE/cleanup/startup_apps.sh" --dry-run || exit $?
fi
if [[ "$mode" == autoclean ]]; then
  auto_clean_state
  printf '%s\n' "$ac_line"
  if [[ $apply -eq 0 ]]; then bash "$AC_DRY" --dry-run || exit $?; fi
fi
if [[ "$mode" == self-update && $apply -eq 0 ]]; then self_update_preview; fi
if [[ $apply -eq 0 ]]; then
  printf '%s\n' 'Preview only. To apply, rerun with an operation followed by --apply. Nothing was changed.'
  exit 0
fi
prune_kit_logs
# --apply is the explicit confirmation for these two: no further question.
if [[ "$mode" == autoclean ]]; then
  if [[ "$ac_state" == On ]]; then bash "$AC_TIMER" --disable; else bash "$AC_TIMER" --enable; fi
  exit $?
fi
if [[ "$mode" == self-update ]]; then self_update_run; exit $?; fi
if [[ ! -t 0 ]]; then printf '%s\n' 'Interactive confirmation required. Nothing was changed.'; exit 1; fi
read -rp "Run it? [y/N] " answer
case "$answer" in y|Y) ;; *) printf '%s\n' 'Cancelled. Nothing was changed.'; exit 0 ;; esac
# On a fresh machine, bootstrap only the approved Node.js runtime using the detected trusted package manager.
# Debloat does not need Node.js.
if [[ "$mode" != update && "$mode" != debloat && "$mode" != startup ]] && ! command -v node >/dev/null; then
  if [[ "$mode" != install && "$mode" != all ]]; then printf '%s\n' 'Install Node.js first using install --apply.'; exit 1; fi
  if command -v apt-get >/dev/null; then sudo apt-get update || exit $?; sudo apt-get install nodejs npm || exit $?
  elif command -v dnf >/dev/null; then sudo dnf install nodejs npm || exit $?
  elif command -v pacman >/dev/null; then sudo pacman -S --needed nodejs npm || exit $?
  elif command -v zypper >/dev/null; then sudo zypper install nodejs || exit $?
  else printf '%s\n' 'Install Node.js from https://nodejs.org/en/download and rerun.'; exit 1; fi
  command -v node >/dev/null || exit 1
fi
if [[ "$mode" == all || "$mode" == install ]]; then bash "$HERE/install/first_install.sh" --apply --all || exit $?; fi
if [[ "$mode" == all || "$mode" == debloat ]]; then bash "$HERE/debloat/debloat_linux.sh" || exit $?; fi
if [[ "$mode" == cache ]]; then bash "$HERE/install/setup_shared_cache.sh" || exit $?; fi
if [[ "$mode" == all || "$mode" == update ]]; then bash "$HERE/update/update_system.sh" --auto || exit $?; fi
if [[ "$mode" == all || "$mode" == clean ]]; then
  node "$HERE/../tools/devcache.mjs" clean-idle --apply; idle_rc=$?
  bash "$HERE/cleanup/clean_dev_caches.sh" --auto; cache_rc=$?
  bash "$HERE/cleanup/clean_system_junk.sh" --auto; junk_rc=$?
  # Interactive terminal: ask which startup items to keep. Otherwise switch off every new item.
  if [[ -t 0 ]]; then start_flag=--review; else start_flag=--auto; fi
  bash "$HERE/cleanup/startup_apps.sh" "$start_flag"; start_rc=$?
  if (( idle_rc != 0 )); then exit $idle_rc; fi
  if (( cache_rc != 0 )); then exit $cache_rc; fi
  if (( junk_rc != 0 )); then exit $junk_rc; fi
  if (( start_rc != 0 )); then exit $start_rc; fi
fi
if [[ "$mode" == startup ]]; then bash "$HERE/cleanup/startup_apps.sh" --review || exit $?; fi
printf '%s\n' 'Finished. Review any manual tool steps and restart if needed.'
