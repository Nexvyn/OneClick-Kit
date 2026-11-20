#!/usr/bin/env bash
# Save My App List - writes the app lists next to this script. Read-only on the system.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"
refuse_sudo

# save_list FILE CMD ARGS... - runs the listing command, cleans the output,
# and writes it to FILE (or only reports the count in dry run).
save_list() {
  local name="$1" data count tmp
  shift
  if ! data="$("$@" 2>/dev/null)"; then
    fail "could not read the list for $name, file left unchanged"
    return 0
  fi
  data="$(printf '%s\n' "$data" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'NF' | sort -u)"
  count="$(printf '%s\n' "$data" | awk 'NF {n++} END {print n + 0}')"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  [dry run] would write %s with %s entries\n' "$name" "$count"
    return 0
  fi
  tmp="$(mktemp "$SCRIPT_DIR/.$name.XXXXXX")" || { fail "could not create a temp file for $name"; return 0; }
  if printf '%s\n' "$data" | awk 'NF' > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$SCRIPT_DIR/$name"; then
    info "Wrote $name ($count entries)"
  else
    rm -f "$tmp"
    fail "could not write $name"
  fi
  return 0
}

zypper_installed() {
  zypper --quiet --no-refresh search --installed-only --type package 2>/dev/null \
    | awk -F'|' 'NR>2 {gsub(/ /,"",$2); if ($2!="") print $2}'
}

snap_names() {
  snap list 2>/dev/null | awk 'NR>1 {print $1}'
}

pacman_foreign() {
  pacman -Qqem 2>/dev/null || true
}

banner "Save My App List"

step 1 3 "System packages"
if have apt-mark; then
  save_list packages-apt.txt apt-mark showmanual
elif have dnf; then
  save_list packages-dnf.txt dnf repoquery --userinstalled --queryformat '%{name}\n'
elif have pacman; then
  save_list packages-pacman.txt pacman -Qqen
  save_list packages-aur.txt pacman_foreign
elif have zypper; then
  save_list packages-zypper.txt zypper_installed
else
  info "No supported package manager found, skipped"
fi

step 2 3 "Flatpak apps"
if have flatpak; then
  save_list flatpak.txt flatpak list --app --columns=application
else
  info "flatpak not found, skipped"
fi

step 3 3 "Snap apps"
if have snap; then
  save_list snap.txt snap_names
else
  info "snap not found, skipped"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  printf '\n%s\n' "Dry run finished. Nothing was written."
else
  printf '\n%s\n' "Saved. Commit these files to keep them with the repo."
fi
pause_end
exit "$RESULT"
