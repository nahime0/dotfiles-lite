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
[[ -L "$HOME/.tmux/themes" ]]
[[ "$(readlink "$HOME/.tmux/themes")" == "$ROOT/config/tmux/themes" ]]
[[ -L "$HOME/.config/nvim" ]]
[[ -d "$HOME/.config/dotfiles-lite" ]]

backup_zshrc=$(find "$HOME/.local/state/dotfiles-lite/backups" -type f -name .zshrc -print -quit)
[[ -n "$backup_zshrc" ]]
[[ "$(cat "$backup_zshrc")" == 'previous zsh configuration' ]]

backup_count_before=$(find "$HOME/.local/state/dotfiles-lite/backups" -type f | wc -l | tr -d ' ')
"$ROOT/install" --profile server --skip-packages --yes
backup_count_after=$(find "$HOME/.local/state/dotfiles-lite/backups" -type f | wc -l | tr -d ' ')
[[ "$backup_count_before" == "$backup_count_after" ]]

dry_home="$TEST_ROOT/dry-home"
HOME="$dry_home" "$ROOT/install" --profile server --skip-packages --dry-run --yes >/dev/null
[[ ! -e "$dry_home" ]]

rollback_home="$TEST_ROOT/rollback-home"
fake_bin="$TEST_ROOT/fake-bin"
mkdir -p "$rollback_home/.tmux/themes" "$fake_bin"
printf 'restore me\n' > "$rollback_home/.zshrc"
printf 'previous tmux theme\n' > "$rollback_home/.tmux/themes/custom.conf"
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
[[ ! -L "$rollback_home/.tmux/themes" ]]
[[ "$(cat "$rollback_home/.tmux/themes/custom.conf")" == 'previous tmux theme' ]]
[[ ! -e "$rollback_home/.config/nvim" ]]

git config --file "$ROOT/config/git/gitconfig" --get init.defaultBranch | grep -qx main

if command -v tmux >/dev/null 2>&1; then
    TMUX_TEST_SOCKET="dotfiles-lite-smoke-$$"
    tmux -L "$TMUX_TEST_SOCKET" -f "$ROOT/config/tmux/tmux.conf" \
        new-session -d -s dotfiles-lite-smoke
    tmux_theme=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gqv @dotfiles_tmux_theme)
    tmux_status_position=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-position)
    tmux_status_style=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-style)
    tmux_status_left=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-left)
    tmux_status_right=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-right)
    tmux_window_current=$(tmux -L "$TMUX_TEST_SOCKET" show-window-options -gv window-status-current-format)
    tmux_active_border=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv pane-active-border-style)

    tmux -L "$TMUX_TEST_SOCKET" source-file "$HOME/.tmux/themes/nord-light.conf"
    tmux_light_theme=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gqv @dotfiles_tmux_theme)
    tmux_light_status_style=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv status-style)
    tmux_light_active_border=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gv pane-active-border-style)

    tmux -L "$TMUX_TEST_SOCKET" source-file "$HOME/.tmux/themes/nord.conf"
    tmux_restored_theme=$(tmux -L "$TMUX_TEST_SOCKET" show-options -gqv @dotfiles_tmux_theme)
    tmux -L "$TMUX_TEST_SOCKET" kill-server
    TMUX_TEST_SOCKET=''

    [[ "$tmux_theme" == nord ]]
    [[ "$tmux_status_position" == top ]]
    [[ "$tmux_status_style" == *"bg=#2E3440"* ]]
    [[ "$tmux_status_left" == *"#S"*""* ]]
    [[ "$tmux_status_right" == *"#H"* ]]
    [[ "$tmux_status_right" == *"client_prefix"* ]]
    [[ "$tmux_window_current" == *""* ]]
    [[ "$tmux_window_current" == *"bg=#88C0D0"* ]]
    [[ "$tmux_active_border" == *"fg=#5E81AC"* ]]
    [[ "$tmux_light_theme" == nord-light ]]
    [[ "$tmux_light_status_style" == *"bg=#E5E9F0"* ]]
    [[ "$tmux_light_active_border" == *"fg=#3B5E85"* ]]
    [[ "$tmux_restored_theme" == nord ]]
fi

if command -v zsh >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # Expanded by the nested Zsh process.
    env -u LANG -u LC_ALL -u LC_CTYPE zsh -dfic '
        source "$1"
        [[ "$LANG" == C.UTF-8 || "$LANG" == C.utf8 ]] || exit 1
        [[ "$(locale charmap)" == UTF-8 ]] || exit 1
    ' _ "$ROOT/config/zsh/zshrc"

    # shellcheck disable=SC2016 # Expanded by the nested Zsh process.
    env -u LC_ALL -u LC_CTYPE LANG=C zsh -dfic '
        source "$1"
        [[ "$LANG" == C ]] || exit 1
    ' _ "$ROOT/config/zsh/zshrc"

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
            [[ "${aliases[yolo.claude]}" == "claude --dangerously-skip-permissions" ]] || exit 1
            [[ "${aliases[yolo.codex]}" == "codex --dangerously-bypass-approvals-and-sandbox" ]] || exit 1
            [[ "${aliases[yolo.kimi]}" == "kimi --yolo" ]] || exit 1
            [[ "${aliases[yolo.grok]}" == "grok --permission-mode bypassPermissions" ]] || exit 1

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
