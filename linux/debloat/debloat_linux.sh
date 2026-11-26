#!/usr/bin/env bash
# Debloat for Linux: turns off news, ads and crash/data sharing, removes a few
# preinstalled extras and stops welcome apps starting at login. Yes items run by
# default. Ask items are asked first and are kept with --auto or --dry-run.
# CUPS, Avahi, Bluetooth and ModemManager are never touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

usage() {
  printf '%s\n' 'Usage: debloat_linux.sh [--auto] [--dry-run]'
  printf '%s\n' '  --auto     skip Ask items (they stay as they are)'
  printf '%s\n' '  --dry-run  print what would change, change nothing'
}
parse_args "$@"

# Ask an owner question. Returns 0 only when the owner answers yes.
ask_item() {
  if [[ $DRY_RUN -eq 1 || $AUTO -eq 1 ]]; then
    info "[ask] $1 (kept)"
    return 1
  fi
  if [[ ! -t 0 ]]; then
    info "[ask] $1 (kept, no terminal)"
    return 1
  fi
  local answer
  read -rp "[ask] $1 [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
  esac
  info "kept"
  return 1
}

pkg_installed() {
  case "$(detect_pm)" in
    apt) dpkg -s "$1" >/dev/null 2>&1 ;;
    dnf|zypper) rpm -q "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Q "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

remove_packages() {
  case "$(detect_pm)" in
    apt) as_root apt-get remove -y "$@" ;;
    dnf) as_root dnf remove -y "$@" ;;
    pacman) as_root pacman -R --noconfirm "$@" ;;
    zypper) as_root zypper --non-interactive remove "$@" ;;
    *) return 1 ;;
  esac
}

# [1/8] Ubuntu APT news and Pro ads
step 1 8 "Ubuntu APT news and Pro ads"
if have pro; then
  as_root pro config set apt_news=false || fail "could not turn off APT news"
else
  info "Ubuntu Pro tool not found, skipped"
fi

# [2/8] MOTD news at login
step 2 8 "MOTD news at login"
motd=/etc/default/motd-news
if [[ ! -f "$motd" ]]; then
  info "$motd not found, skipped"
elif grep -q '^ENABLED=0' "$motd"; then
  info "MOTD news already off"
elif grep -q '^ENABLED=' "$motd"; then
  as_root sed -i 's/^ENABLED=.*/ENABLED=0/' "$motd" || fail "could not change $motd"
else
  info "No ENABLED line in $motd, skipped"
fi

# [3/8] Ubuntu data sharing (Insights and Report)
step 3 8 "Ubuntu data sharing (Insights and Report)"
if have ubuntu-report; then
  run ubuntu-report -f send no || fail "ubuntu-report could not opt out"
fi
if have ubuntu-insights; then
  run ubuntu-insights consent -s=false || fail "ubuntu-insights could not opt out"
fi
if ! have ubuntu-report && ! have ubuntu-insights; then
  info "No Ubuntu data-sharing tool found, skipped"
fi

# [4/8] Popularity Contest
step 4 8 "Popularity Contest"
if have dpkg && pkg_installed popularity-contest; then
  as_root apt-get remove -y popularity-contest || fail "could not remove popularity-contest"
else
  info "popularity-contest not installed, skipped"
fi

# [5/8] Crash-report popups (Ask)
step 5 8 "Crash-report popups"
if [[ -f /etc/default/apport ]]; then
  if ask_item "Turn off Apport crash-report popups?"; then
    as_root systemctl disable --now apport || fail "could not disable apport"
    as_root sed -i 's/^enabled=.*/enabled=0/' /etc/default/apport || fail "could not change /etc/default/apport"
  fi
else
  info "Apport not found, skipped"
fi
if have abrt-auto-reporting; then
  if ask_item "Turn off ABRT automatic crash reporting?"; then
    as_root abrt-auto-reporting disabled || fail "could not turn off ABRT reporting"
  fi
fi

# [6/8] Preinstalled games (Ask)
step 6 8 "Preinstalled games"
games=()
for pkg in aisleriot gnome-mines gnome-sudoku gnome-mahjongg kmines kpat; do
  if pkg_installed "$pkg"; then games+=("$pkg"); fi
done
if [[ ${#games[@]} -eq 0 ]]; then
  info "No preinstalled games found, skipped"
else
  info "Found: ${games[*]}"
  if ask_item "Remove these preinstalled games?"; then
    remove_packages "${games[@]}" || fail "could not remove the preinstalled games"
  fi
fi

# [7/8] Welcome apps at login (turned off, app kept)
step 7 8 "Welcome apps at login (turned off, app kept)"
found_welcome=0
for name in mintwelcome manjaro-hello welcome eos-welcome zorin-welcome; do
  src="/etc/xdg/autostart/$name.desktop"
  dst="$HOME/.config/autostart/$name.desktop"
  if [[ ! -f "$src" ]]; then continue; fi
  found_welcome=1
  if [[ -f "$dst" ]] && grep -q '^Hidden=true' "$dst"; then
    info "$name autostart already off"
    continue
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry run] would turn off autostart for $name"
    continue
  fi
  mkdir -p "$HOME/.config/autostart" || { fail "could not create ~/.config/autostart"; break; }
  if sed -e '/^Hidden=/d' -e '/^\[Desktop Entry\]/a Hidden=true' "$src" > "$dst"; then
    info "turned off autostart for $name (the app stays installed)"
  else
    fail "could not write $dst"
  fi
done
if [[ $found_welcome -eq 0 ]]; then info "No welcome app autostart found, skipped"; fi

# [8/8] Summary
step 8 8 "Done"
if [[ $DRY_RUN -eq 1 ]]; then
  info 'Dry run finished. Nothing was changed.'
else
  info 'Debloat finished. Ask items you kept are unchanged. Restart the session to see the login changes.'
fi
exit "$RESULT"
