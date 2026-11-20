# shellcheck shell=bash
# Shared helpers for the OneClick Kit Linux scripts. Sourced, never executed.

shopt -s nullglob

AUTO=0
DRY_RUN=0
RESULT=0

# parse_args "$@" - sets AUTO and DRY_RUN, handles -h/--help.
parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --auto) AUTO=1 ;;
      --dry-run|--dryrun) DRY_RUN=1 ;;
      -h|--help)
        if declare -F usage >/dev/null; then
          usage
        else
          printf 'Usage: %s [--auto] [--dry-run]\n' "$(basename "$0")"
        fi
        exit 0
        ;;
      *) printf '  WARNING: unknown option ignored: %s\n' "$arg" ;;
    esac
  done
}

# refuse_sudo - user-level scripts must not run under sudo ($HOME would be root's).
refuse_sudo() {
  if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
    printf 'Run this without sudo. It asks for your password when it needs it.\n'
    exit 1
  fi
}

banner() {
  local line='============================================================'
  if [[ $AUTO -eq 0 && -t 1 ]]; then clear; fi
  printf '\n%s\n' "$line"
  printf '  %s\n' "$1"
  printf '%s\n' "$line"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  DRY RUN - nothing will be changed.\n'
  fi
}

step() {
  printf '\n[%s/%s] %s\n' "$1" "$2" "$3"
}

info() {
  printf '  %s\n' "$1"
}

fail() {
  printf '  WARNING: %s\n' "$1"
  RESULT=1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

# run CMD ARGS... - executes the command, or only reports it in dry run.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  [dry run] would run: %s\n' "$*"
    return 0
  fi
  "$@"
}

# as_root CMD ARGS... - runs through sudo unless already root.
as_root() {
  if [[ $EUID -eq 0 ]]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

# empty_dir DIR [--root] - deletes the contents of DIR, keeps DIR.
empty_dir() {
  local dir="$1" flag="${2:-}"
  while [[ "$dir" == */ && "$dir" != / ]]; do
    dir="${dir%/}"
  done
  if [[ -z "$dir" ]]; then return 0; fi
  if [[ ! -d "$dir" ]]; then return 0; fi
  case "$dir" in
    /|/home|/root|/usr|/etc|/var|/tmp|/boot|/opt)
      printf '  refusing to empty %s\n' "$dir"
      RESULT=1
      return 1
      ;;
  esac
  if [[ -n "${HOME:-}" && "$dir" == "${HOME%/}" ]]; then
    printf '  refusing to empty %s\n' "$dir"
    RESULT=1
    return 1
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  [dry run] would empty %s\n' "$dir"
    return 0
  fi
  if [[ "$flag" == "--root" ]]; then
    as_root find "$dir" -xdev -mindepth 1 -delete || { fail "could not empty $dir"; return 1; }
  else
    find "$dir" -xdev -mindepth 1 -delete || { fail "could not empty $dir"; return 1; }
  fi
  return 0
}

# detect_pm - echoes apt | dnf | pacman | zypper | none
detect_pm() {
  if have apt-get; then
    echo apt
  elif have dnf; then
    echo dnf
  elif have pacman; then
    echo pacman
  elif have zypper; then
    echo zypper
  else
    echo none
  fi
}

# free_mb - free space on / in MB
free_mb() {
  df -Pm / | awk 'NR==2 {print $4}'
}

# reboot_needed - returns 0 when a restart is needed
reboot_needed() {
  if [[ -e /var/run/reboot-required ]]; then return 0; fi
  if have needs-restarting; then
    local rc
    needs-restarting -r >/dev/null 2>&1
    rc=$?
    if [[ $rc -eq 1 ]]; then return 0; fi
  fi
  local kver
  kver="$(uname -r 2>/dev/null)"
  if [[ -d /usr/lib/modules && -n "$kver" && ! -d "/usr/lib/modules/$kver" ]]; then
    return 0
  fi
  return 1
}

pause_end() {
  if [[ $AUTO -eq 0 && -t 0 ]]; then
    read -rp "Press Enter to close..." _
  fi
}

# countdown SECONDS "message" - only interactive, non-dry runs
countdown() {
  if [[ $AUTO -eq 0 && $DRY_RUN -eq 0 && -t 0 ]]; then
    printf '%s\n' "$2"
    printf 'Starting in %s s. Press Ctrl+C to cancel.\n' "$1"
    sleep "$1"
  fi
}
