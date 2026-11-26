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
dry_run=0
for arg in "$@"; do
  [[ "$arg" == --auto ]] && continue
  [[ "$arg" == --apply ]] && apply=1
  [[ "$arg" == --dry-run || "$arg" == --dryrun ]] && dry_run=1
  args+=("$arg")
done
browser_status=0
if [[ $apply -eq 1 ]]; then
  node "$SCRIPT_DIR/../../tools/browsers.mjs" --apply; browser_status=$?
else
  node "$SCRIPT_DIR/../../tools/browsers.mjs"; browser_status=$?
fi
node "$SCRIPT_DIR/../../tools/install-development.mjs" "${args[@]}"
status=$?
[[ $status -gt 1 ]] && exit "$status"
if [[ $apply -eq 1 ]]; then
  bash "$SCRIPT_DIR/setup_shared_cache.sh" --auto || exit $?
fi
# Git and SSH setup: preview only in plan mode, interactive when applying.
git_args=()
if [[ $apply -eq 0 || $dry_run -eq 1 ]]; then
  git_args+=(--dry-run)
fi
printf '%s\n' 'Also sets up the Git identity and GitHub SSH key (setup_git.sh).'
bash "$SCRIPT_DIR/setup_git.sh" ${git_args[@]+"${git_args[@]}"}
if [[ $apply -eq 1 && $browser_status -ne 0 ]]; then
  printf '%s\n' 'Some browsers did not install. See the list above.'
  exit 1
fi

exit "$status"
