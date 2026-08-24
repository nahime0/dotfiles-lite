alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -m'
alias gd='git diff'
alias gp='git push'
alias gpu='git pull --rebase'
alias gis='git status --short --branch'
alias gsta='git stash'
alias gstap='git stash pop'

# Explicitly unrestricted modes for trusted, disposable environments.
alias yolo.claude='claude --dangerously-skip-permissions'
alias yolo.codex='codex --dangerously-bypass-approvals-and-sandbox'
alias yolo.kimi='kimi --yolo'
alias yolo.grok='grok --permission-mode bypassPermissions'

if (( $+commands[eza] )); then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -la --icons=auto --group-directories-first'
    alias lt='eza --tree --icons=auto --group-directories-first'
fi

if (( $+commands[bat] )); then
    alias cat='bat --paging=never'
elif (( $+commands[batcat] )); then
    alias cat='batcat --paging=never'
fi

if (( $+commands[fd] )); then
    alias find='fd'
elif (( $+commands[fdfind] )); then
    alias find='fdfind'
fi

if (( $+commands[rg] )); then
    alias grep='rg'
fi

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi

if (( $+commands[fzf] )) && [[ -t 0 && -t 1 ]]; then
    if fzf --zsh >/dev/null 2>&1; then
        source <(fzf --zsh)
    else
        [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
        [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
    fi
fi

if (( $+commands[nvim] )); then
    export EDITOR='nvim'
    export VISUAL='nvim'
elif (( $+commands[vim] )); then
    export EDITOR='vim'
    export VISUAL='vim'
else
    export EDITOR='vi'
    export VISUAL='vi'
fi
