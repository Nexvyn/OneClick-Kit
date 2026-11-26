#!/usr/bin/env bash
# Git identity, default branch and GitHub SSH key. Asks only when run interactively.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
  printf 'Usage: %s [--auto] [--dry-run]\n' "$(basename "$0")"
  printf '  --auto     print the status only, ask nothing\n'
  printf '  --dry-run  print what would run, change nothing, ask nothing\n'
}

parse_args "$@"
banner "Git and SSH Setup"

# interactive - 0 when questions may be asked.
interactive() {
  [[ $AUTO -eq 0 && $DRY_RUN -eq 0 ]]
}

# ask_yes QUESTION - 0 only when the user answers y or yes.
# Without a terminal the answer is No, so the script never hangs.
ask_yes() {
  local reply=""
  if [[ ! -t 0 ]]; then
    printf '  No terminal input here, so the answer is No.\n' >&2
    return 1
  fi
  read -r -p "  $1 " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ask_text QUESTION - prints what the user typed, empty when skipped.
ask_text() {
  local reply=""
  if [[ ! -t 0 ]]; then
    printf '  No terminal input here, so this value is not set.\n' >&2
    return 0
  fi
  read -r -p "  $1 " reply
  printf '%s' "$reply"
}

git_value() {
  git config --global "$1" 2>/dev/null
}

if ! have git; then
  info "Git is not installed. Install it with your package manager, then rerun this script."
  exit 0
fi

name="$(git_value user.name)"
email="$(git_value user.email)"
branch="$(git_value init.defaultBranch)"
pub="$HOME/.ssh/id_ed25519.pub"
key_present=0
[[ -f "$pub" ]] && key_present=1
gh_ok=0
have gh && gh_ok=1

step 1 1 "Current status"
info "Git:            found"
info "User name:      ${name:-not set}"
info "User email:     ${email:-not set}"
info "Default branch: ${branch:-not set}"
info "SSH key:        $([[ $key_present -eq 1 ]] && echo present || echo missing)"
info "GitHub CLI gh:  $([[ $gh_ok -eq 1 ]] && echo installed || echo not installed)"

if [[ $AUTO -eq 1 ]]; then
  exit 0
fi

# Git identity: set only the values that are empty. Existing values are never overwritten.
if [[ -z "$name" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would ask for your Git user name."
    run git config --global user.name "your-name"
  else
    name="$(ask_text "Your name for Git commits:")"
    if [[ -n "$name" ]]; then
      run git config --global user.name "$name" || fail "could not set user.name"
    fi
  fi
fi

if [[ -z "$email" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would ask for your Git email."
    run git config --global user.email "your-email"
  else
    email="$(ask_text "Your email for Git commits:")"
    if [[ -n "$email" ]]; then
      run git config --global user.email "$email" || fail "could not set user.email"
    fi
  fi
fi

if [[ -z "$branch" ]]; then
  run git config --global init.defaultBranch main || fail "could not set init.defaultBranch"
fi

# SSH key for GitHub.
if [[ $key_present -eq 0 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would ask: Create an SSH key for GitHub? Y/N"
    run ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519"
  elif ask_yes "Create an SSH key for GitHub? Y/N"; then
    if ! have ssh-keygen; then
      fail "ssh-keygen is not installed, so no key was created"
    else
      mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
      if run ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519"; then
        key_present=1
        info "Your public key:"
        cat "$pub"
        info "Add it at https://github.com/settings/keys"
      else
        fail "ssh-keygen did not create the key"
      fi
    fi
  else
    info "No SSH key created."
  fi
fi

# Optional upload with gh, only when gh is signed in.
if [[ $gh_ok -eq 1 && ( $key_present -eq 1 || $DRY_RUN -eq 1 ) ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would ask to upload the key with gh when gh is signed in."
    run gh ssh-key add "$pub" --title "${HOSTNAME:-computer} OneClick Kit"
  elif gh auth status >/dev/null 2>&1 && ask_yes "Upload it to GitHub now with gh? Y/N"; then
    run gh ssh-key add "$pub" --title "${HOSTNAME:-computer} OneClick Kit" || fail "gh could not add the key"
  fi
fi

printf '\n'
info "Git and SSH setup finished."
exit "$RESULT"
