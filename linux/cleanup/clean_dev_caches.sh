#!/usr/bin/env bash
# Developer Cache Cleanup - npm, pnpm, yarn, bun and pip caches (user level, no sudo).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"
refuse_sudo

# dev_clean TOOL CMD ARGS... - runs a cache command; failures are info only.
dev_clean() {
  local tool="$1"
  shift
  if ! have "$tool"; then
    info "$tool not found, skipped"
    return 0
  fi
  if ! run "$@"; then
    info "$tool cache clean did not finish (ignored)"
  fi
  return 0
}

banner "Developer Cache Cleanup"
before="$(free_mb)"

step 1 1 "Developer package caches"
dev_clean npm npm cache clean --force
dev_clean pnpm pnpm store prune
dev_clean yarn yarn cache clean
dev_clean bun bun pm cache rm
if have pip3; then
  run pip3 cache purge || info "pip3 cache purge did not finish (ignored)"
elif have pip; then
  run pip cache purge || info "pip cache purge did not finish (ignored)"
else
  info "pip not found, skipped"
fi

after="$(free_mb)"
if [[ "$before" =~ ^[0-9]+$ && "$after" =~ ^[0-9]+$ ]]; then
  freed=$((after - before))
  if (( freed < 0 )); then freed=0; fi
  info "Freed about ${freed} MB on /"
else
  info "Free space could not be measured."
fi

printf '\n%s\n' "Developer cache cleanup finished. Projects re-download packages the next time they install."
pause_end
exit "$RESULT"
