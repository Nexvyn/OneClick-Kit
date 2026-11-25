#!/usr/bin/env bash
# Curated profile only. Exported application restore remains a separate command.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v node >/dev/null; then
  printf '%s\n' 'Install Node.js from https://nodejs.org/en/download, then rerun this script.'
  exit 1
fi
args=()
apply=0
for arg in "$@"; do
  [[ "$arg" == --auto ]] && continue
  [[ "$arg" == --apply ]] && apply=1
  args+=("$arg")
done
node "$SCRIPT_DIR/../../tools/install-development.mjs" "${args[@]}"
status=$?
[[ $status -gt 1 ]] && exit "$status"
if [[ $apply -eq 1 ]]; then
  bash "$SCRIPT_DIR/setup_shared_cache.sh" --auto || exit $?
fi

exit "$status"
