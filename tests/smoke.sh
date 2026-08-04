#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lite-test.XXXXXX")
TMUX_TEST_SOCKET=''

cleanup() {
    if [[ -n "$TMUX_TEST_SOCKET" ]] && command -v tmux >/dev/null 2>&1; then
        tmux -L "$TMUX_TEST_SOCKET" kill-server >/dev/null 2>&1 || true
    fi

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

if command -v tmux >/dev/null 2>&1; then
    TMUX_TEST_SOCKET="dotfiles-lite-smoke-$$"
    tmux -L "$TMUX_TEST_SOCKET" -f "$ROOT/config/tmux/tmux.conf" \
        new-session -d -s dotfiles-lite-smoke
    tmux_status_style=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-style)
    tmux_status_left=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-left)
    tmux_status_right=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-right)
    tmux_window_current=$(tmux -L "$TMUX_TEST_SOCKET" show-window-options -gv window-status-current-style)
    tmux -L "$TMUX_TEST_SOCKET" kill-server
    TMUX_TEST_SOCKET=''

    [[ "$tmux_status_style" == *"bg=#2E3440"* ]]
    [[ "$tmux_status_left" == *"#S"* ]]
    [[ "$tmux_status_right" == *"#h"* ]]
    [[ "$tmux_status_right" == *"client_prefix"* ]]
    [[ "$tmux_status_right" == *"window_zoomed_flag"* ]]
    [[ "$tmux_window_current" == *"bg=#88C0D0"* ]]
fi

if command -v zsh >/dev/null 2>&1; then
    prompt_repo="$TEST_ROOT/prompt-repo"
    git init -q -b main "$prompt_repo"
    printf 'tracked\n' > "$prompt_repo/tracked.txt"
    git -C "$prompt_repo" add tracked.txt
    git -C "$prompt_repo" -c user.name=Test -c user.email=test@example.invalid \
        -c commit.gpgsign=false commit -qm initial

    (
        cd "$prompt_repo"
        zsh -dfic '
            source "$1"
            DOTFILES_PROMPT_STARTED=$((EPOCHREALTIME - 3.2))
            false
            _dotfiles_lite_prompt_precmd
            [[ "$DOTFILES_PROMPT_LAST_STATUS" -eq 1 ]] || exit 1
            [[ -n "$DOTFILES_PROMPT_DURATION" ]] || exit 1
            [[ "$DOTFILES_PROMPT_SYMBOL" == *"#BF616A"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_RIGHT" == *"%m"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_RIGHT" == *"exit 1"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_GIT" == *"git:main"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_GIT" != *"+"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_GIT" != *"*"* ]] || exit 1

            print changed >> tracked.txt
            true
            _dotfiles_lite_prompt_precmd
            [[ "$DOTFILES_PROMPT_GIT" == *"*"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_GIT" != *"+"* ]] || exit 1

            command git add tracked.txt || exit 1
            true
            _dotfiles_lite_prompt_precmd
            [[ "$DOTFILES_PROMPT_GIT" == *"+"* ]] || exit 1
            [[ "$DOTFILES_PROMPT_GIT" != *"*"* ]] || exit 1

            command git switch -q -c "percent%branch" || exit 1
            true
            _dotfiles_lite_prompt_precmd
            [[ "$DOTFILES_PROMPT_GIT" == *"git:percent%%branch"* ]] || exit 1

            DOTFILES_PROMPT_STARTED=$((EPOCHREALTIME - 65.4))
            true
            _dotfiles_lite_prompt_precmd
            [[ "$DOTFILES_PROMPT_LAST_STATUS" -eq 0 ]] || exit 1
            [[ "$DOTFILES_PROMPT_DURATION" == "1m5s" ]] || exit 1
            [[ "$DOTFILES_PROMPT_RIGHT" != *"exit"* ]] || exit 1

            true
            _dotfiles_lite_prompt_precmd
            [[ -z "$DOTFILES_PROMPT_DURATION" ]] || exit 1
            [[ "$DOTFILES_PROMPT_RIGHT" == "%F{#81A1C1}%m%f" ]] || exit 1
        ' _ "$ROOT/config/zsh/zshrc" "$prompt_repo"
    )
fi

if grep -R '/Users/' "$ROOT/config" >/dev/null 2>&1; then
    printf 'Found a workstation-specific /Users path in managed configuration.\n' >&2
    exit 1
fi

printf 'dotfiles-lite smoke test passed.\n'
