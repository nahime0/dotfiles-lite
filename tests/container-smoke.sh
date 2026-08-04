#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)
IMAGE=${1:-debian:12-slim}

command -v docker >/dev/null 2>&1 || {
    printf 'docker is required for the container smoke test.\n' >&2
    exit 1
}

docker run --rm \
    --volume "$ROOT:/source:ro" \
    "$IMAGE" \
    bash -lc '
        set -Eeuo pipefail
        cp -a /source /tmp/dotfiles-lite
        TERM=xterm-kitty /tmp/dotfiles-lite/install --profile server --yes
        TERM=xterm-kitty /tmp/dotfiles-lite/install --profile server --yes
        test -L "$HOME/.zshrc"
        test -L "$HOME/.tmux.conf"
        test -L "$HOME/.config/nvim"
        git config --global --get init.defaultBranch | grep -qx main
        zsh -lic '\''alias t >/dev/null; [[ "$EDITOR" == nvim ]]'\''
        TERM=screen-256color tmux -L dotfiles-lite-status new-session -d -s dotfiles-lite-status
        TERM=screen-256color tmux -L dotfiles-lite-status show-options -gv status-right | grep -q "#h"
        TERM=screen-256color tmux -L dotfiles-lite-status show-window-options -gv window-status-current-style | grep -q "bg=#88C0D0"
        TERM=screen-256color tmux -L dotfiles-lite-status kill-server
        nvim --headless +quitall
    '
