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
        /tmp/dotfiles-lite/install --profile server --yes
        /tmp/dotfiles-lite/install --profile server --yes
        test -L "$HOME/.zshrc"
        test -L "$HOME/.tmux.conf"
        test -L "$HOME/.config/nvim"
        git config --global --get init.defaultBranch | grep -qx main
        zsh -dfi -c exit
        nvim --headless +quitall
    '
