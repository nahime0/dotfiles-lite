history_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p "$history_dir"

HISTFILE="$history_dir/history"
HISTSIZE=50000
SAVEHIST=50000

setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt inc_append_history
setopt share_history

unset history_dir
