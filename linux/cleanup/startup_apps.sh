#!/usr/bin/env bash
# startup_apps.sh - turns off login programs (XDG autostart) for the current user.
#
# Items are the *.desktop files in ~/.config/autostart (user) and
# /etc/xdg/autostart (system). An item counts as ON unless its [Desktop Entry]
# section has Hidden=true or X-GNOME-Autostart-enabled=false.
#
# Turning an item off never deletes anything and never changes system files:
#   - user item: Hidden=true is set in its own file (an existing Hidden line is
#     replaced, otherwise the line is added at the end of [Desktop Entry]).
#   - system item: it is copied to ~/.config/autostart/<same name>, then the
#     copy gets Hidden=true. /etc/xdg is only read, never written.
# Before a user file is edited, <file>.oneclick-bak is saved once. An existing
# backup is never overwritten. To undo by hand, copy the .oneclick-bak back over
# the file. For a system item, delete the copy in ~/.config/autostart instead.
#
# Items named in ~/.config/oneclick-kit/startup-keep (one per line, the file name
# without .desktop, case-insensitive) are kept on. Protected items (desktop
# session, keyring, audio, input methods, OneClick Kit itself) are never turned off.
#
# Modes (exactly one):
#   --dry-run  print what would change; change nothing, no backups, no keep file, no log
#   --auto     turn off every enabled item that is not protected and not kept
#   --review   ask which items to keep; the typed numbers become the new keep list
#
# Changes are logged to ~/.local/state/oneclick-kit/logs/startup-apps-<time>.log

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

USER_AUTOSTART="$HOME/.config/autostart"
SYSTEM_AUTOSTART="/etc/xdg/autostart"
KEEP_FILE="$HOME/.config/oneclick-kit/startup-keep"
LOG_DIR="$HOME/.local/state/oneclick-kit/logs"
LOG_FILE="$LOG_DIR/startup-apps-$(date +%Y%m%d-%H%M%S).log"

MODE=""
ITEM_NAME=()
ITEM_PATH=()
ITEM_WHERE=()
declare -A SEEN=()
declare -A KEEP=()

usage() {
  cat <<'EOF'
Usage: startup_apps.sh --dry-run | --auto | --review

  --dry-run  show what would be turned off; change nothing
  --auto     turn off every enabled startup program that is not protected
             and not listed in ~/.config/oneclick-kit/startup-keep
  --review   list the enabled startup programs and ask which to keep

Use exactly one mode.
EOF
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# desktop_value FILE KEY - value of KEY in the [Desktop Entry] section (last one wins).
desktop_value() {
  local file="$1" key="$2"
  tr -d '\r' < "$file" 2>/dev/null | awk -v key="$key" '
    /^\[/ { insec = ($0 == "[Desktop Entry]"); next }
    insec && index($0, key "=") == 1 { value = substr($0, length(key) + 2) }
    END { printf "%s", value }
  '
}

has_desktop_section() {
  tr -d '\r' < "$1" 2>/dev/null | grep -q '^\[Desktop Entry\]$'
}

# is_disabled FILE - true when the item is switched off in its file.
is_disabled() {
  local hidden gnome
  hidden="$(to_lower "$(desktop_value "$1" Hidden)")"
  gnome="$(to_lower "$(desktop_value "$1" X-GNOME-Autostart-enabled)")"
  [[ "$hidden" == "true" || "$gnome" == "false" ]]
}

# is_protected NAME FILE - true for session, system and OneClick items that must never change.
is_protected() {
  local hay pat
  hay="$(to_lower "$1 $(desktop_value "$2" Exec)")"
  for pat in gnome-keyring polkit at-spi pulseaudio pipewire xdg-user-dirs ibus fcitx \
             nm-applet blueman evolution-alarm tracker localsearch gnome-shell \
             plasmashell xfce4-session mate-session cinnamon unity gsd- \
             org.gnome.shell org.gnome.settingsdaemon oneclick; do
    if [[ "$hay" == *"$pat"* ]]; then return 0; fi
  done
  if [[ "$hay" == *print* && "$hay" == *applet* ]]; then return 0; fi
  return 1
}

load_keep() {
  local line
  [[ -f "$KEEP_FILE" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "${line%$'\r'}")"
    line="${line%.desktop}"
    if [[ -n "$line" ]]; then
      KEEP["$(to_lower "$line")"]=1
    fi
  done < "$KEEP_FILE"
}

is_kept() {
  local key
  key="$(to_lower "$1")"
  [[ -n "${KEEP[$key]:-}" ]]
}

# add_item FILE WHERE - records an enabled item. A user file hides a system file of the same name.
add_item() {
  local file="$1" where="$2" name
  name="$(basename "$file" .desktop)"
  if [[ -n "${SEEN[$name]:-}" ]]; then return 0; fi
  SEEN["$name"]=1
  if ! has_desktop_section "$file"; then return 0; fi
  if is_disabled "$file"; then return 0; fi
  ITEM_NAME+=("$name")
  ITEM_PATH+=("$file")
  ITEM_WHERE+=("$where")
}

discover_items() {
  local f
  for f in "$USER_AUTOSTART"/*.desktop; do
    add_item "$f" user
  done
  for f in "$SYSTEM_AUTOSTART"/*.desktop; do
    add_item "$f" system
  done
}

log_line() {
  if ! mkdir -p "$LOG_DIR" || ! printf '%s\n' "$1" >> "$LOG_FILE"; then
    fail "could not write log $LOG_FILE"
  fi
}

# set_hidden FILE - saves FILE.oneclick-bak once, then sets Hidden=true in [Desktop Entry].
set_hidden() {
  local file="$1" tmp
  if [[ ! -e "$file.oneclick-bak" ]]; then
    cp -p "$file" "$file.oneclick-bak" || return 1
  fi
  tmp="$(mktemp "$file.tmp.XXXXXX")" || return 1
  if ! tr -d '\r' < "$file" | awk '
    function close_section() {
      if (insec && !hidden_done) { print "Hidden=true"; hidden_done = 1 }
    }
    /^\[/ {
      close_section()
      insec = ($0 == "[Desktop Entry]")
      print
      next
    }
    insec && /^Hidden=/ {
      if (!hidden_done) { print "Hidden=true"; hidden_done = 1 }
      next
    }
    { print }
    END { close_section() }
  ' > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp" > "$file" && rm -f "$tmp"
}

# disable_item NAME PATH WHERE - turns one enabled item off (user file, or a copy for system items).
disable_item() {
  local name="$1" path="$2" where="$3" target="$2"
  if [[ "$where" == "system" ]]; then
    target="$USER_AUTOSTART/$name.desktop"
    if [[ -e "$target" ]]; then
      fail "$target already exists; $name not changed"
      return 1
    fi
    if ! mkdir -p "$USER_AUTOSTART" || ! cp "$path" "$target"; then
      fail "could not copy $name to $USER_AUTOSTART"
      return 1
    fi
  fi
  if ! set_hidden "$target"; then
    fail "could not disable $name"
    return 1
  fi
  log_line "disabled $name ($where) -> $target"
  printf 'disabled: %s (%s)\n' "$name" "$where"
}

# process_items - dry run or auto mode over every enabled item.
process_items() {
  local i name where
  if [[ ${#ITEM_NAME[@]} -eq 0 ]]; then
    printf 'no enabled startup programs found.\n'
    return 0
  fi
  for ((i = 0; i < ${#ITEM_NAME[@]}; i++)); do
    name="${ITEM_NAME[$i]}"
    where="${ITEM_WHERE[$i]}"
    if is_protected "$name" "${ITEM_PATH[$i]}"; then
      printf 'protected: %s\n' "$name"
    elif is_kept "$name"; then
      printf 'kept: %s\n' "$name"
    elif [[ "$MODE" == "dry" ]]; then
      printf '[dry run] would disable %s (%s)\n' "$name" "$where"
    else
      disable_item "$name" "${ITEM_PATH[$i]}" "$where"
    fi
  done
}

# save_keep NAME... - rewrites the keep file with exactly these names (zero names = empty file).
save_keep() {
  local n
  mkdir -p "$(dirname "$KEEP_FILE")" || return 1
  {
    for n in "$@"; do
      printf '%s\n' "$n"
    done
  } > "$KEEP_FILE"
}

run_review() {
  local i n name ans key tok old_sig="" new_sig="" keep_changed=0
  local -a cand=() keep_names=() disable_idx=() toks=()
  local -A pick=()

  if [[ ! -t 0 ]]; then
    printf 'stdin is not a terminal; running --auto instead.\n'
    process_items
    return $?
  fi

  for ((i = 0; i < ${#ITEM_NAME[@]}; i++)); do
    if is_protected "${ITEM_NAME[$i]}" "${ITEM_PATH[$i]}"; then continue; fi
    cand+=("$i")
  done
  if [[ ${#cand[@]} -eq 0 ]]; then
    printf 'no startup programs to review.\n'
    return 0
  fi

  printf '\nEnabled startup programs:\n'
  for ((n = 1; n <= ${#cand[@]}; n++)); do
    i="${cand[$((n - 1))]}"
    name="${ITEM_NAME[$i]}"
    if is_kept "$name"; then
      printf '  %d. %s (%s) (kept)\n' "$n" "$name" "${ITEM_WHERE[$i]}"
    else
      printf '  %d. %s (%s)\n' "$n" "$name" "${ITEM_WHERE[$i]}"
    fi
  done

  printf '\nType the numbers to KEEP starting with Windows, separated by spaces, or press Enter to keep none of them: '
  read -r ans
  read -ra toks <<< "$ans"
  for tok in "${toks[@]}"; do
    if [[ "$tok" =~ ^[0-9]+$ ]] && (( 10#$tok >= 1 && 10#$tok <= ${#cand[@]} )); then
      pick[$((10#$tok))]=1
    else
      printf 'ignored: %s\n' "$tok"
    fi
  done

  for key in "${!KEEP[@]}"; do
    old_sig+="$key"$'\n'
  done
  for ((n = 1; n <= ${#cand[@]}; n++)); do
    i="${cand[$((n - 1))]}"
    if [[ -n "${pick[$n]:-}" ]]; then
      keep_names+=("${ITEM_NAME[$i]}")
      new_sig+="$(to_lower "${ITEM_NAME[$i]}")"$'\n'
    else
      disable_idx+=("$i")
    fi
  done

  if [[ "$(printf '%s' "$old_sig" | sort)" != "$(printf '%s' "$new_sig" | sort)" ]]; then
    keep_changed=1
  fi
  if [[ $keep_changed -eq 0 && ${#disable_idx[@]} -eq 0 ]]; then
    printf 'no changes.\n'
    return 0
  fi

  if [[ $keep_changed -eq 1 ]]; then
    if ! save_keep "${keep_names[@]}"; then
      fail "could not save $KEEP_FILE"
      return 1
    fi
    log_line "keep list saved to $KEEP_FILE: ${keep_names[*]:-none}"
    printf 'keep list saved: %s\n' "${keep_names[*]:-none}"
  fi

  for i in "${disable_idx[@]}"; do
    disable_item "${ITEM_NAME[$i]}" "${ITEM_PATH[$i]}" "${ITEM_WHERE[$i]}"
  done
}

MODE_COUNT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry"; MODE_COUNT=$((MODE_COUNT + 1)) ;;
    --auto) MODE="auto"; MODE_COUNT=$((MODE_COUNT + 1)) ;;
    --review) MODE="review"; MODE_COUNT=$((MODE_COUNT + 1)) ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$arg"; usage; exit 1 ;;
  esac
done
if [[ $MODE_COUNT -eq 0 ]]; then
  usage
  exit 0
fi
if [[ $MODE_COUNT -gt 1 ]]; then
  printf 'use only one mode\n'
  usage
  exit 1
fi

refuse_sudo
if [[ "$MODE" == "dry" ]]; then
  printf 'DRY RUN - nothing will be changed.\n'
fi

load_keep
discover_items

case "$MODE" in
  dry|auto) process_items ;;
  review) run_review ;;
esac

exit "$RESULT"
