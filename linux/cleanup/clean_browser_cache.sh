#!/usr/bin/env bash
# Browser Cache Cleanup - deletes browser caches only (user level, no sudo).
# History, cookies, passwords, logins, bookmarks, sessions, Local Storage,
# IndexedDB and extensions are never touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"
parse_args "$@"
refuse_sudo

BROWSER_PROCS=(chrome chromium chromium-browser brave msedge firefox firefox-bin)

banner "Browser Cache Cleanup"

# [1/3] Close browsers
step 1 3 "Close browsers"
running=()
if ! have pgrep; then
  info "pgrep not found, browsers not closed"
else
  for p in "${BROWSER_PROCS[@]}"; do
    if pgrep -x "$p" >/dev/null 2>&1; then
      running+=("$p")
    fi
  done
  if [[ ${#running[@]} -eq 0 ]]; then
    info "No browsers are running."
  else
    countdown 10 "Chrome, Chromium, Brave, Edge and Firefox will be closed. Save your work first."
    for p in "${running[@]}"; do
      run pkill -TERM -x "$p"
    done
    if [[ $DRY_RUN -eq 0 ]]; then
      for ((i = 0; i < 5; i++)); do
        still=0
        for p in "${running[@]}"; do
          if pgrep -x "$p" >/dev/null 2>&1; then still=1; fi
        done
        if [[ $still -eq 0 ]]; then break; fi
        sleep 1
      done
    fi
    for p in "${running[@]}"; do
      if [[ $DRY_RUN -eq 1 ]] || pgrep -x "$p" >/dev/null 2>&1; then
        run pkill -KILL -x "$p"
      fi
    done
  fi
fi

# [2/3] Chromium-family browsers
step 2 3 "Chromium-family browsers"
for d in \
  "$HOME/.cache/google-chrome" \
  "$HOME/.cache/chromium" \
  "$HOME/.cache/BraveSoftware/Brave-Browser" \
  "$HOME/.cache/microsoft-edge" \
  "$HOME/.var/app/com.google.Chrome/cache" \
  "$HOME/.var/app/org.chromium.Chromium/cache" \
  "$HOME/.var/app/com.brave.Browser/cache" \
  "$HOME/.var/app/com.microsoft.Edge/cache"; do
  empty_dir "$d"
done

for base in \
  "$HOME/.config/google-chrome" \
  "$HOME/.config/chromium" \
  "$HOME/.config/BraveSoftware/Brave-Browser" \
  "$HOME/.config/microsoft-edge"; do
  if [[ ! -d "$base" ]]; then continue; fi
  info "Cleaning $(basename "$base") cache..."
  for profile in "$base/Default" "$base"/Profile\ * "$base/Guest Profile"; do
    for sub in "Code Cache" GPUCache DawnCache DawnGraphiteCache DawnWebGPUCache; do
      empty_dir "$profile/$sub"
    done
  done
  for sub in ShaderCache GrShaderCache GraphiteDawnCache; do
    empty_dir "$base/$sub"
  done
done

# [3/3] Firefox
step 3 3 "Firefox"
firefox_found=0
for root in \
  "$HOME/.cache/mozilla/firefox" \
  "$HOME/snap/firefox/common/.cache/mozilla/firefox" \
  "$HOME/.var/app/org.mozilla.firefox/cache/mozilla/firefox"; do
  if [[ ! -d "$root" ]]; then continue; fi
  firefox_found=1
  for prof in "$root"/*/; do
    for sub in cache2 startupCache thumbnails; do
      empty_dir "${prof%/}/$sub"
    done
  done
done
if [[ $firefox_found -eq 0 ]]; then
  info "Firefox not found, skipped"
fi

printf '\n%s\n' "Browser cache cleanup finished. History, cookies, passwords and logins were not touched."
pause_end
exit "$RESULT"
