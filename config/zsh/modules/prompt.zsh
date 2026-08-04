# A small native prompt using Nord-like colors. It has no framework or font
# dependency and only starts Git after finding a repository with Zsh builtins.
autoload -Uz add-zsh-hook
zmodload zsh/nearcolor 2>/dev/null || true

if zmodload zsh/datetime 2>/dev/null; then
    typeset -g DOTFILES_PROMPT_HAS_DATETIME=true
else
    typeset -g DOTFILES_PROMPT_HAS_DATETIME=false
fi

typeset -g DOTFILES_PROMPT_STARTED=''
typeset -g DOTFILES_PROMPT_DURATION=''
typeset -gi DOTFILES_PROMPT_LAST_STATUS=0
typeset -g DOTFILES_PROMPT_SYMBOL='%F{#A3BE8C}❯%f'
typeset -g DOTFILES_PROMPT_RIGHT='%F{#81A1C1}%m%f'
typeset -g DOTFILES_PROMPT_GIT=''

_dotfiles_lite_prompt_git() {
    local search_dir=$PWD
    local git_dir=''
    local git_link=''
    local head=''
    local branch=''
    local action=''
    local status_output=''
    local line=''
    local staged=''
    local unstaged=''

    DOTFILES_PROMPT_GIT=''

    while true; do
        if [[ -d "$search_dir/.git" ]]; then
            git_dir="$search_dir/.git"
            break
        elif [[ -f "$search_dir/.git" ]]; then
            IFS= read -r git_link < "$search_dir/.git" || return 0
            [[ "$git_link" == 'gitdir: '* ]] || return 0
            git_dir=${git_link#gitdir: }
            [[ "$git_dir" == /* ]] || git_dir="$search_dir/$git_dir"
            break
        fi

        [[ "$search_dir" == / ]] && return 0
        search_dir=${search_dir:h}
    done

    IFS= read -r head < "$git_dir/HEAD" || return 0
    if [[ "$head" == 'ref: refs/heads/'* ]]; then
        branch=${head#ref: refs/heads/}
    else
        branch=${head[1,7]:-detached}
    fi

    status_output=$(command git --no-optional-locks status --porcelain --untracked-files=no 2>/dev/null) || return 0
    for line in ${(f)status_output}; do
        [[ "${line[1]}" != ' ' && "${line[1]}" != '?' ]] && staged='+'
        [[ "${line[2]}" != ' ' ]] && unstaged='*'
    done

    if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
        action='rebase'
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        action='merge'
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        action='cherry-pick'
    elif [[ -f "$git_dir/REVERT_HEAD" ]]; then
        action='revert'
    elif [[ -f "$git_dir/BISECT_LOG" ]]; then
        action='bisect'
    fi

    # Branch names may legally contain %, which has meaning during prompt
    # expansion. Doubling it keeps the branch name literal.
    branch=${branch//\%/%%}
    DOTFILES_PROMPT_GIT=' %F{#B48EAD}git:'"$branch"'%f'
    [[ -n "$action" ]] && DOTFILES_PROMPT_GIT+=' %F{#EBCB8B}('"$action"')%f'
    [[ -n "$staged$unstaged" ]] && DOTFILES_PROMPT_GIT+='%F{#EBCB8B}'"$staged$unstaged"'%f'
}

_dotfiles_lite_prompt_preexec() {
    if [[ "$DOTFILES_PROMPT_HAS_DATETIME" == true ]]; then
        DOTFILES_PROMPT_STARTED=$EPOCHREALTIME
    fi
}

_dotfiles_lite_prompt_precmd() {
    local last_status=$?
    local -F 3 elapsed=0
    local -i rounded_seconds=0
    local -i minutes=0
    local -i seconds=0

    DOTFILES_PROMPT_LAST_STATUS=$last_status
    DOTFILES_PROMPT_DURATION=''

    if [[ "$DOTFILES_PROMPT_HAS_DATETIME" == true && -n "$DOTFILES_PROMPT_STARTED" ]]; then
        elapsed=$((EPOCHREALTIME - DOTFILES_PROMPT_STARTED))

        if (( elapsed >= 2.0 )); then
            if (( elapsed >= 60.0 )); then
                rounded_seconds=$((elapsed + 0.5))
                minutes=$((rounded_seconds / 60))
                seconds=$((rounded_seconds % 60))
                DOTFILES_PROMPT_DURATION="${minutes}m${seconds}s"
            else
                printf -v DOTFILES_PROMPT_DURATION '%.1fs' "$elapsed"
            fi
        fi
    fi
    DOTFILES_PROMPT_STARTED=''

    _dotfiles_lite_prompt_git

    if (( EUID == 0 )); then
        DOTFILES_PROMPT_SYMBOL='%F{#BF616A}#%f'
    elif (( DOTFILES_PROMPT_LAST_STATUS == 0 )); then
        DOTFILES_PROMPT_SYMBOL='%F{#A3BE8C}❯%f'
    else
        DOTFILES_PROMPT_SYMBOL='%F{#BF616A}❯%f'
    fi

    DOTFILES_PROMPT_RIGHT='%F{#81A1C1}%m%f'
    if [[ -n "$DOTFILES_PROMPT_DURATION" ]]; then
        DOTFILES_PROMPT_RIGHT+=' %F{#4C566A}·%f %F{#EBCB8B}'"$DOTFILES_PROMPT_DURATION"'%f'
    fi
    if (( DOTFILES_PROMPT_LAST_STATUS != 0 )); then
        DOTFILES_PROMPT_RIGHT+=' %F{#4C566A}·%f %F{#BF616A}exit '"$DOTFILES_PROMPT_LAST_STATUS"'%f'
    fi

    return 0
}

add-zsh-hook preexec _dotfiles_lite_prompt_preexec
add-zsh-hook precmd _dotfiles_lite_prompt_precmd

setopt prompt_subst
PROMPT='%F{#81A1C1}%n%f %F{#88C0D0}%~%f${DOTFILES_PROMPT_GIT}'$'\n''${DOTFILES_PROMPT_SYMBOL} '
RPROMPT='${DOTFILES_PROMPT_RIGHT}'
