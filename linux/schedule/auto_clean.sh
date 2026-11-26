#!/usr/bin/env bash
# OneClick Kit automatic cleanup. Started by the user timer (auto_clean_timer.sh), no sudo.
# Usage: auto_clean.sh [--dry-run]   (--dry-run changes nothing and writes no log or timestamp)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

DAY=86400
PLAN_LIMIT=20
PLAN_COUNT=0
USER_NAME="${USER:-$(id -un)}"
STATE_DIR="$HOME/.local/state/oneclick-kit"
LOG_DIR="$STATE_DIR/logs"
STAMP_FILE="$STATE_DIR/auto-clean-state"
TRASH_DIR="$HOME/.local/share/Trash"
LOG_FILE=""

# reset_count - starts the capped output block of one step.
reset_count() {
  PLAN_COUNT=0
}

# note TEXT - prints one item line; only the first PLAN_LIMIT lines of a step are shown.
note() {
  PLAN_COUNT=$((PLAN_COUNT + 1))
  if (( PLAN_COUNT <= PLAN_LIMIT )); then
    printf '  %s\n' "$*"
  fi
}

# note_end - reports how many item lines the cap hid.
note_end() {
  if (( PLAN_COUNT > PLAN_LIMIT )); then
    printf '  ... and %d more not shown\n' $((PLAN_COUNT - PLAN_LIMIT))
  fi
}

# run_step NUMBER TITLE FUNCTION - one guarded step; a failure is reported and the next step still runs.
run_step() {
  local number="$1" title="$2" fn="$3"
  printf '\n[%s/7] %s\n' "$number" "$title"
  if ! "$fn"; then
    fail "$title did not finish (continuing with the other steps)"
  fi
  note_end
}

# try_cmd TOOL ARGS... - runs a tool when it is installed; dry run only reports the command.
try_cmd() {
  local tool="$1"
  shift
  if ! have "$tool"; then
    info "$tool not found, skipped"
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    note "[dry run] would run: $tool $*"
    return 0
  fi
  "$tool" "$@"
}

# clean_temp - user-owned files in /tmp and /var/tmp older than 2 days, then empty user-owned dirs.
clean_temp() {
  reset_count
  local -a dirs=()
  local dir path
  for dir in /tmp /var/tmp; do
    if [[ -d "$dir" ]]; then dirs+=("$dir"); fi
  done
  if (( ${#dirs[@]} == 0 )); then
    info "no temp folders found"
    return 0
  fi
  while IFS= read -r -d '' path; do
    if [[ $DRY_RUN -eq 1 ]]; then
      note "[dry run] would delete $path"
    elif rm -f -- "$path" 2>/dev/null; then
      note "deleted $path"
    else
      note "could not delete $path"
    fi
  done < <(find "${dirs[@]}" -xdev -user "$USER_NAME" ! -name claude -type f -mtime +2 -print0 2>/dev/null)
  while IFS= read -r -d '' path; do
    if [[ $DRY_RUN -eq 1 ]]; then
      note "[dry run] would delete empty folder $path"
    elif rmdir -- "$path" 2>/dev/null; then
      note "deleted empty folder $path"
    else
      note "could not delete empty folder $path"
    fi
  done < <(find "${dirs[@]}" -xdev -mindepth 1 -depth -user "$USER_NAME" ! -name claude -type d -empty -mtime +2 -print0 2>/dev/null)
  return 0
}

# clean_trash - removes trash items whose DeletionDate is older than 14 days.
clean_trash() {
  reset_count
  local info_dir="$TRASH_DIR/info"
  local files_dir="$TRASH_DIR/files"
  local info stamp epoch name item now cutoff
  if [[ ! -d "$info_dir" ]]; then
    info "no trash folder found"
    return 0
  fi
  now="$(date +%s)"
  cutoff=$((now - 14 * DAY))
  for info in "$info_dir"/*.trashinfo; do
    [[ -f "$info" ]] || continue
    stamp="$(sed -n 's/^DeletionDate=//p' "$info" | head -n 1 | tr -d '\r')"
    if [[ ! "$stamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
      continue
    fi
    epoch="$(date -d "$stamp" +%s 2>/dev/null)" || continue
    if (( epoch >= cutoff )); then
      continue
    fi
    name="$(basename "$info" .trashinfo)"
    if [[ -z "$name" || "$name" == "." || "$name" == ".." ]]; then
      continue
    fi
    item="$files_dir/$name"
    if [[ $DRY_RUN -eq 1 ]]; then
      note "[dry run] would delete trash item $item (deleted $stamp)"
      note "[dry run] would delete $info"
    else
      rm -rf -- "$item" 2>/dev/null
      if rm -f -- "$info" 2>/dev/null; then
        note "deleted trash item $item (deleted $stamp)"
      else
        note "could not delete $info"
      fi
    fi
  done
  return 0
}

# run_dev_cache_idle - project caches that are idle; the tool's default run only previews.
run_dev_cache_idle() {
  reset_count
  local devcache="$REPO_DIR/tools/devcache.mjs"
  if ! have node; then
    info "node not found, skipped"
    return 0
  fi
  if [[ ! -f "$devcache" ]]; then
    fail "devcache.mjs not found at $devcache"
    return 1
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    note "[dry run] would run: node $devcache clean-idle --unattended"
    return 0
  fi
  node "$devcache" clean-idle --unattended
}

# prune_stores - pnpm store prune and npm cache verify (only when installed).
prune_stores() {
  reset_count
  local rc=0
  try_cmd pnpm store prune || rc=1
  try_cmd npm cache verify || rc=1
  return "$rc"
}

# weekly_dev_clean - runs clean_dev_caches.sh --auto when the last run is 7 or more days old.
weekly_dev_clean() {
  reset_count
  local now last="" rc=0
  now="$(date +%s)"
  if [[ -f "$STAMP_FILE" ]]; then
    last="$(head -n 1 "$STAMP_FILE" 2>/dev/null | tr -d '[:space:]')"
  fi
  if [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < 7 * DAY )); then
    info "last weekly cache clean was $(( (now - last) / DAY )) day(s) ago, not due"
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    note "[dry run] would run: bash $REPO_DIR/linux/cleanup/clean_dev_caches.sh --auto"
    note "[dry run] would write timestamp $now to $STAMP_FILE"
    return 0
  fi
  bash "$REPO_DIR/linux/cleanup/clean_dev_caches.sh" --auto || rc=1
  mkdir -p "$STATE_DIR" && printf '%s\n' "$now" > "$STAMP_FILE" || rc=1
  return "$rc"
}

# run_startup_apps - turns off new startup programs (the keep list and protected items are respected); dry run only previews.
run_startup_apps() {
  reset_count
  local script="$REPO_DIR/linux/cleanup/startup_apps.sh"
  if [[ ! -f "$script" ]]; then
    fail "startup_apps.sh not found at $script"
    return 1
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    bash "$script" --dry-run
    return $?
  fi
  bash "$script" --auto
}

# prune_logs - deletes auto-clean logs older than 30 days.
prune_logs() {
  reset_count
  local log
  if [[ ! -d "$LOG_DIR" ]]; then
    info "no log folder yet"
    return 0
  fi
  while IFS= read -r -d '' log; do
    if [[ $DRY_RUN -eq 1 ]]; then
      note "[dry run] would delete old log $log"
    elif rm -f -- "$log" 2>/dev/null; then
      note "deleted old log $log"
    else
      note "could not delete old log $log"
    fi
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -mtime +30 -print0 2>/dev/null)
  return 0
}

# start_log - writes all further output to a new log file as well as the terminal.
start_log() {
  mkdir -p "$LOG_DIR" || return 1
  LOG_FILE="$LOG_DIR/auto-clean-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

main() {
  parse_args "$@"
  refuse_sudo

  if [[ $DRY_RUN -eq 0 ]]; then
    start_log || fail "could not create the log file under $LOG_DIR"
  fi

  printf 'OneClick Kit auto-clean started %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf 'DRY RUN - nothing will be changed, no log or timestamp is written.\n'
  fi

  run_step 1 "Old temp files in /tmp and /var/tmp" clean_temp
  run_step 2 "Trash items deleted more than 14 days ago" clean_trash
  run_step 3 "Idle project caches (devcache)" run_dev_cache_idle
  run_step 4 "Package store prune (pnpm, npm)" prune_stores
  run_step 5 "Weekly developer cache clean" weekly_dev_clean
  run_step 6 "Startup apps (new programs turned off)" run_startup_apps
  run_step 7 "Old auto-clean logs (over 30 days)" prune_logs

  printf '\n'
  if [[ $DRY_RUN -eq 1 ]]; then
    printf 'Dry run finished. Nothing was changed.\n'
  else
    printf 'Auto-clean finished. Log: %s\n' "$LOG_FILE"
  fi
  exit "$RESULT"
}

main "$@"
