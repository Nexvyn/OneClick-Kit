#!/usr/bin/env bash
# System Updates - packages, Flatpak and Snap apps, firmware (fwupd).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"

# pm_upgrade PM - real package upgrade for the detected package manager.
pm_upgrade() {
  case "$1" in
    apt)
      as_root apt-get update && as_root env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
      ;;
    dnf)
      as_root dnf upgrade --refresh -y
      ;;
    pacman)
      as_root pacman -Syu --noconfirm
      ;;
    zypper)
      as_root zypper --non-interactive refresh || return 1
      if grep -qE '^ID="?opensuse-tumbleweed"?$' /etc/os-release 2>/dev/null; then
        as_root zypper --non-interactive dup
      else
        as_root zypper --non-interactive update
      fi
      ;;
  esac
}

banner "System Updates"

# [1/3] Packages
pm="$(detect_pm)"
step 1 3 "Packages"
if [[ "$pm" == none ]]; then
  fail "No supported package manager found"
elif [[ $DRY_RUN -eq 1 ]]; then
  case "$pm" in
    apt) apt list --upgradable 2>/dev/null ;;
    dnf) dnf check-update ;;
    pacman)
      if have checkupdates; then
        checkupdates
      else
        info "checkupdates not found, list skipped"
      fi
      ;;
    zypper) zypper --non-interactive list-updates ;;
  esac
  printf '  [dry run] would upgrade all packages\n'
else
  pm_upgrade "$pm" || fail "Package upgrade did not finish"
fi

# [2/3] Flatpak and Snap apps
step 2 3 "Flatpak and Snap apps"
if have flatpak; then
  run flatpak update --user -y --noninteractive || fail "Flatpak user app update did not finish"
  as_root flatpak update --system -y --noninteractive || fail "Flatpak system app update did not finish"
else
  info "flatpak not found, skipped"
fi
if have snap; then
  as_root snap refresh || fail "Snap refresh did not finish"
else
  info "snap not found, skipped"
fi

# [3/3] Firmware and drivers
step 3 3 "Firmware and drivers (fwupd)"
if have fwupdmgr; then
  as_root fwupdmgr refresh --force || fail "fwupdmgr refresh did not finish"
  as_root fwupdmgr update -y --no-reboot-check
  fw_rc=$?
  # 2 means nothing to update, which is fine.
  if [[ $fw_rc -ne 0 && $fw_rc -ne 2 ]]; then
    fail "Firmware update exited with code $fw_rc"
  fi
else
  info "fwupdmgr not found, firmware skipped"
fi

# Restart check
if [[ $DRY_RUN -eq 1 ]]; then
  info "Restart check skipped in dry run."
elif reboot_needed; then
  info "A restart is needed to finish installing updates."
  if [[ $AUTO -eq 0 && -t 0 ]]; then
    read -rp "Restart now? [y/N] " ans
    case "$ans" in
      y|Y) as_root systemctl reboot ;;
    esac
  fi
else
  info "No restart needed."
fi

printf '\n%s\n' "Updates finished."
if [[ $RESULT -eq 1 ]]; then
  printf '%s\n' "Some steps had problems - see the warnings above."
fi
pause_end
exit "$RESULT"
