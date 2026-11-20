#!/usr/bin/env bash
# Install My Apps - installs the lists written by save_my_apps.sh.
# Runs as the user; system installs go through sudo (as_root).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"
refuse_sudo

# read_list FILE - fills the global array LIST with trimmed entries,
# skipping blank lines and comments.
read_list() {
  local line
  local -a raw=()
  LIST=()
  mapfile -t raw < "$1"
  for line in "${raw[@]}"; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -z "$line" || "$line" == \#* || "$line" == -* ]]; then continue; fi
    LIST+=("$line")
  done
}

# install_one PM PACKAGE - installs one package with the package manager.
install_one() {
  local pm="$1" p="$2"
  case "$pm" in
    apt) as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" ;;
    dnf) as_root dnf install -y "$p" ;;
    pacman) as_root pacman -S --needed --noconfirm "$p" ;;
    zypper) as_root zypper --non-interactive install "$p" ;;
    *) return 1 ;;
  esac
}

# install_packages PM - one package at a time, so one bad name does not stop the rest.
install_packages() {
  local pm="$1" file="$SCRIPT_DIR/packages-$1.txt" p ok=0 bad=0
  if [[ ! -f "$file" ]]; then
    fail "packages-$pm.txt not found. Run save_my_apps.sh on your old PC first."
    return 0
  fi
  read_list "$file"
  if [[ "$pm" == apt ]]; then
    as_root apt-get update || fail "apt-get update did not finish"
  fi
  for p in "${LIST[@]}"; do
    if install_one "$pm" "$p"; then
      ok=$((ok + 1))
    else
      bad=$((bad + 1))
      fail "could not install $p"
    fi
  done
  info "Installed $ok, failed $bad."
  return 0
}

banner "Install My Apps"
pm="$(detect_pm)"

step 1 3 "System packages ($pm)"
if [[ "$pm" == none ]]; then
  fail "No supported package manager found"
else
  install_packages "$pm"
fi

step 2 3 "Flatpak apps"
if [[ -f "$SCRIPT_DIR/flatpak.txt" ]] && have flatpak; then
  run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    || fail "could not add the Flathub remote"
  read_list "$SCRIPT_DIR/flatpak.txt"
  for id in "${LIST[@]}"; do
    run flatpak install --user -y --noninteractive flathub "$id" || fail "could not install Flatpak $id"
  done
else
  info "flatpak.txt or flatpak not found, skipped"
fi

step 3 3 "Snap apps"
if [[ -f "$SCRIPT_DIR/snap.txt" ]] && have snap; then
  read_list "$SCRIPT_DIR/snap.txt"
  for name in "${LIST[@]}"; do
    as_root snap install "$name" || as_root snap install --classic "$name" || fail "could not install snap $name"
  done
else
  info "snap.txt or snap not found, skipped"
fi

printf '\n%s\n' "Install finished."
pause_end
exit "$RESULT"
