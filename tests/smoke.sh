#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lite-test.XXXXXX")

cleanup() {
    case "$TEST_ROOT" in
        "${TMPDIR:-/tmp}"/dotfiles-lite-test.*) rm -rf -- "$TEST_ROOT" ;;
        *) printf 'Refusing to remove unexpected test path: %s\n' "$TEST_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
printf 'previous zsh configuration\n' > "$HOME/.zshrc"

"$ROOT/install" --profile server --skip-packages --skip-checks --yes

[[ -L "$HOME/.zshrc" ]]
[[ "$(readlink "$HOME/.zshrc")" == "$ROOT/config/zsh/zshrc" ]]
[[ -L "$HOME/.zprofile" ]]
[[ -L "$HOME/.gitconfig" ]]
[[ -L "$HOME/.gitignore" ]]
[[ -L "$HOME/.tmux.conf" ]]
[[ -L "$HOME/.config/nvim" ]]
[[ -d "$HOME/.config/dotfiles-lite" ]]

backup_zshrc=$(find "$HOME/.local/state/dotfiles-lite/backups" -type f -name .zshrc -print -quit)
[[ -n "$backup_zshrc" ]]
[[ "$(cat "$backup_zshrc")" == 'previous zsh configuration' ]]

backup_count_before=$(find "$HOME/.local/state/dotfiles-lite/backups" -type f | wc -l | tr -d ' ')
"$ROOT/install" --profile server --skip-packages --skip-checks --yes
backup_count_after=$(find "$HOME/.local/state/dotfiles-lite/backups" -type f | wc -l | tr -d ' ')
[[ "$backup_count_before" == "$backup_count_after" ]]

dry_home="$TEST_ROOT/dry-home"
HOME="$dry_home" "$ROOT/install" --profile server --skip-packages --skip-checks --dry-run --yes >/dev/null
[[ ! -e "$dry_home" ]]

rollback_home="$TEST_ROOT/rollback-home"
fake_bin="$TEST_ROOT/fake-bin"
mkdir -p "$rollback_home" "$fake_bin"
printf 'restore me\n' > "$rollback_home/.zshrc"
ln -s "$(type -P false)" "$fake_bin/nvim"

if HOME="$rollback_home" PATH="$fake_bin:$PATH" \
    "$ROOT/install" --profile server --skip-packages --yes >/dev/null 2>&1; then
    printf 'Expected the injected Neovim validation failure.\n' >&2
    exit 1
fi

[[ ! -L "$rollback_home/.zshrc" ]]
[[ "$(cat "$rollback_home/.zshrc")" == 'restore me' ]]
[[ ! -e "$rollback_home/.zprofile" ]]
[[ ! -e "$rollback_home/.gitconfig" ]]
[[ ! -e "$rollback_home/.tmux.conf" ]]
[[ ! -e "$rollback_home/.config/nvim" ]]

git config --file "$ROOT/config/git/gitconfig" --get init.defaultBranch | grep -qx main

if grep -R '/Users/' "$ROOT/config" >/dev/null 2>&1; then
    printf 'Found a workstation-specific /Users path in managed configuration.\n' >&2
    exit 1
fi

printf 'dotfiles-lite smoke test passed.\n'
