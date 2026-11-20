#!/usr/bin/env bash
# System Junk Cleanup - package caches, old logs, old temp files, crash
# reports, thumbnails, Trash, unused Flatpak runtimes and old Snap revisions.
# System parts run through sudo (as_root).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"

banner "System Junk Cleanup"

# [1/6] Package cache
step 1 6 "Package cache"
before="$(free_mb)"
pm="$(detect_pm)"
case "$pm" in
  apt)
    as_root apt-get clean || fail "apt-get clean did not finish"
    as_root apt-get autoremove --purge -y || fail "apt-get autoremove did not finish"
    ;;
  dnf)
    as_root dnf clean all || fail "dnf clean all did not finish"
    as_root dnf autoremove -y || fail "dnf autoremove did not finish"
    ;;
  pacman)
    if have paccache; then
      as_root paccache -rk2 || fail "paccache -rk2 did not finish"
      as_root paccache -ruk0 || fail "paccache -ruk0 did not finish"
    else
      as_root pacman -Sc --noconfirm || fail "pacman -Sc did not finish"
    fi
    ;;
  zypper)
    as_root zypper --non-interactive clean --all || fail "zypper clean did not finish"
    ;;
  none)
    info "No supported package manager found, skipped"
    ;;
esac

# [2/6] System logs
step 2 6 "System logs older than 7 days"
if have journalctl; then
  as_root journalctl --vacuum-time=7d || fail "journalctl --vacuum-time did not finish"
else
  info "journalctl not found, skipped"
fi

# [3/6] Temp files
step 3 6 "Temp files older than 7 days"
tmp_dirs=()
for d in /tmp /var/tmp; do
  if [[ -d "$d" ]]; then tmp_dirs+=("$d"); fi
done
if [[ ${#tmp_dirs[@]} -eq 0 ]]; then
  info "No temp folders found, skipped"
else
  as_root find "${tmp_dirs[@]}" -xdev -mindepth 1 -type f -mtime +7 -delete || fail "old temp files could not all be removed"
fi

# [4/6] Crash reports
step 4 6 "Crash reports"
empty_dir /var/crash --root
empty_dir /var/lib/systemd/coredump --root

# [5/6] Thumbnails and Trash
step 5 6 "Your thumbnails and Trash"
empty_dir "$HOME/.cache/thumbnails"
empty_dir "$HOME/.local/share/Trash/files"
empty_dir "$HOME/.local/share/Trash/info"

# [6/6] Unused Flatpak runtimes and old Snap revisions
step 6 6 "Unused Flatpak runtimes and old Snap revisions"
if have flatpak; then
  run flatpak uninstall --user --unused -y --noninteractive || fail "user Flatpak cleanup did not finish"
  as_root flatpak uninstall --system --unused -y --noninteractive || fail "system Flatpak cleanup did not finish"
else
  info "flatpak not found, skipped"
fi
if have snap; then
  while read -r name rev; do
    if [[ -z "$name" || -z "$rev" ]]; then continue; fi
    as_root snap remove "$name" --revision="$rev" || fail "could not remove snap $name revision $rev"
  done < <(snap list --all 2>/dev/null | awk '/disabled/ {print $1, $3}')
else
  info "snap not found, skipped"
fi

after="$(free_mb)"
if [[ "$before" =~ ^[0-9]+$ && "$after" =~ ^[0-9]+$ ]]; then
  freed=$((after - before))
  if (( freed < 0 )); then freed=0; fi
  info "Freed about ${freed} MB on /"
else
  info "Free space could not be measured."
fi

printf '\n%s\n' "System junk cleanup finished."
pause_end
exit "$RESULT"
