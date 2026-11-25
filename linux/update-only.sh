#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  --apply) [[ $# -eq 1 ]] || exit 2; bash "$HERE/update/update_system.sh" ;;
  ''|--dry-run) [[ $# -le 1 ]] || exit 2; bash "$HERE/update/update_system.sh" --dry-run ;;
  *) printf '%s\n' 'Usage: update-only.sh [--dry-run|--apply]'; exit 2 ;;
esac
