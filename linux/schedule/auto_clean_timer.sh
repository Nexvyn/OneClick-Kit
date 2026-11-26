#!/usr/bin/env bash
# Turns the automatic cleanup on or off as a systemd user timer (every 2 days, AC power only).
# Usage: auto_clean_timer.sh --enable | --disable | --status | --dry-run   (no sudo)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUTO_SCRIPT="$SCRIPT_DIR/auto_clean.sh"
UNIT_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="oneclick-autoclean.service"
TIMER_NAME="oneclick-autoclean.timer"
SERVICE_FILE="$UNIT_DIR/$SERVICE_NAME"
TIMER_FILE="$UNIT_DIR/$TIMER_NAME"

usage() {
  cat <<'EOF'
Usage: auto_clean_timer.sh --enable | --disable | --status | --dry-run
  --enable   install and start the automatic cleanup timer (every 2 days, AC power only)
  --disable  stop the timer and remove its unit files
  --status   print whether auto-clean is On or Off (read-only)
  --dry-run  print the unit files and commands; changes nothing
EOF
}

# service_unit - prints the oneshot service unit.
service_unit() {
  cat <<EOF
[Unit]
Description=OneClick Kit automatic cleanup
ConditionACPower=true

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash "$AUTO_SCRIPT"
Nice=19
IOSchedulingClass=idle
EOF
}

# timer_unit - prints the timer unit.
timer_unit() {
  cat <<'EOF'
[Unit]
Description=Run OneClick Kit automatic cleanup every 2 days

[Timer]
OnBootSec=15min
OnUnitActiveSec=2d
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

have_systemctl() {
  command -v systemctl >/dev/null 2>&1
}

# do_enable - writes both unit files, then enables and starts the timer.
do_enable() {
  if ! have_systemctl; then
    printf 'systemctl was not found. Auto-clean needs systemd user timers, so nothing was installed.\n'
    return 0
  fi
  if ! mkdir -p "$UNIT_DIR"; then
    printf 'Could not create %s\n' "$UNIT_DIR"
    return 1
  fi
  if ! service_unit > "$SERVICE_FILE"; then
    printf 'Could not write %s\n' "$SERVICE_FILE"
    return 1
  fi
  if ! timer_unit > "$TIMER_FILE"; then
    printf 'Could not write %s\n' "$TIMER_FILE"
    return 1
  fi
  if ! systemctl --user daemon-reload; then
    printf 'systemctl --user daemon-reload failed.\n'
    return 1
  fi
  if ! systemctl --user enable --now "$TIMER_NAME"; then
    printf 'Could not enable %s\n' "$TIMER_NAME"
    return 1
  fi
  printf 'Auto-clean enabled: runs every 2 days while on AC power.\n'
  return 0
}

# do_disable - stops the timer, then removes both unit files.
do_disable() {
  if ! have_systemctl; then
    printf 'systemctl was not found. Auto-clean is not installed here, so nothing was changed.\n'
    return 0
  fi
  if [[ ! -f "$TIMER_FILE" && ! -f "$SERVICE_FILE" ]]; then
    printf 'Auto-clean is already off.\n'
    return 0
  fi
  local rc=0
  if ! systemctl --user disable --now "$TIMER_NAME"; then
    printf 'Could not disable %s (removing the unit files anyway).\n' "$TIMER_NAME"
    rc=1
  fi
  if ! rm -f -- "$TIMER_FILE" "$SERVICE_FILE"; then
    printf 'Could not remove the unit files in %s\n' "$UNIT_DIR"
    rc=1
  fi
  if [[ $rc -eq 0 ]]; then
    printf 'Auto-clean disabled.\n'
  fi
  return "$rc"
}

# do_status - read-only; the first stdout line is exactly "Auto-clean: On" or "Auto-clean: Off".
do_status() {
  if ! have_systemctl; then
    printf 'systemctl was not found, so auto-clean cannot run on this system.\n' >&2
    printf 'Auto-clean: Off\n'
    return 0
  fi
  if systemctl --user is-enabled --quiet "$TIMER_NAME" 2>/dev/null; then
    local next
    next="$(systemctl --user show -p NextElapseUSecRealtime --value "$TIMER_NAME" 2>/dev/null)"
    if [[ -z "$next" || "$next" == "n/a" ]]; then
      next="unknown"
    fi
    printf 'Auto-clean: On\n'
    printf 'Next run: %s\n' "$next"
  else
    printf 'Auto-clean: Off\n'
  fi
  return 0
}

# do_dry_run - prints what --enable and --disable would write and run; changes nothing.
do_dry_run() {
  printf '# Would write %s\n' "$SERVICE_FILE"
  service_unit
  printf '\n# Would write %s\n' "$TIMER_FILE"
  timer_unit
  printf '\n# --enable would run:\n'
  printf '[dry run] would run: systemctl --user daemon-reload\n'
  printf '[dry run] would run: systemctl --user enable --now %s\n' "$TIMER_NAME"
  printf '\n# --disable would run:\n'
  printf '[dry run] would run: systemctl --user disable --now %s\n' "$TIMER_NAME"
  printf '[dry run] would remove %s and %s\n' "$TIMER_FILE" "$SERVICE_FILE"
  if ! have_systemctl; then
    printf '\nNote: systemctl was not found on this system, so --enable and --disable would do nothing.\n'
  fi
  return 0
}

main() {
  local action="" count=0 arg
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi
  for arg in "$@"; do
    case "$arg" in
      --enable|--disable|--status|--dry-run)
        action="$arg"
        count=$((count + 1))
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$arg" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
  if [[ $count -ne 1 ]]; then
    printf 'Give exactly one option.\n' >&2
    usage >&2
    exit 1
  fi

  case "$action" in
    --enable) do_enable ;;
    --disable) do_disable ;;
    --status) do_status ;;
    --dry-run) do_dry_run ;;
  esac
  exit $?
}

main "$@"
