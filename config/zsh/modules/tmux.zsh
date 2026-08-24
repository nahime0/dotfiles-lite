# Select a tmux theme from the client terminal without requiring server-side
# desktop settings. An explicit light/dark override always wins.

_dotfiles_lite_tmux_theme_from_rgb() {
    emulate -L zsh
    setopt extended_glob

    local response=$1 red green blue
    local -i red_value green_value blue_value brightness

    [[ "$response" == *'rgb:'* ]] || return 1
    response=${response#*rgb:}
    red=${response%%/*}
    [[ "$red" != "$response" ]] || return 1
    response=${response#*/}
    green=${response%%/*}
    [[ "$green" != "$response" ]] || return 1
    blue=${response#*/}
    blue=${blue%%[^[:xdigit:]]*}

    [[ ${#red} -ge 2 && ${#green} -ge 2 && ${#blue} -ge 2 ]] || return 1
    red=${red[1,2]}
    green=${green[1,2]}
    blue=${blue[1,2]}
    [[ "$red" == [[:xdigit:]]## && "$green" == [[:xdigit:]]## && "$blue" == [[:xdigit:]]## ]] || return 1

    red_value=$(( 16#$red ))
    green_value=$(( 16#$green ))
    blue_value=$(( 16#$blue ))
    brightness=$(( (299 * red_value + 587 * green_value + 114 * blue_value) / 1000 ))

    (( brightness >= 160 )) && print -r -- light || print -r -- dark
}

_dotfiles_lite_tmux_query_terminal_theme() {
    emulate -L zsh

    [[ -t 0 && -t 1 && -r /dev/tty && -w /dev/tty ]] || return 1

    local saved_tty reply='' char
    local -i chars=0
    saved_tty=$(command stty -g </dev/tty) || return 1

    {
        command stty -echo -icanon min 0 time 1 </dev/tty || return 1
        print -n -- $'\e]11;?\e\\' >/dev/tty

        while (( chars < 64 )); do
            IFS= read -r -k 1 -t 0.2 char </dev/tty || break
            reply+=$char
            (( chars++ ))
            [[ "$reply" == *$'\a' || "$reply" == *$'\e\\' ]] && break
        done
    } always {
        command stty "$saved_tty" </dev/tty
    }

    _dotfiles_lite_tmux_theme_from_rgb "$reply"
}

_dotfiles_lite_tmux_detect_theme() {
    emulate -L zsh

    case "${DOTFILES_LITE_TMUX_THEME:-auto}" in
        light|dark)
            print -r -- "$DOTFILES_LITE_TMUX_THEME"
            return 0
            ;;
    esac

    local colorfgbg=${COLORFGBG:-} background
    background=${colorfgbg##*[;:]}
    if [[ -n "$colorfgbg" && "$background" == <-> ]]; then
        (( background >= 7 )) && print -r -- light || print -r -- dark
        return 0
    fi

    _dotfiles_lite_tmux_query_terminal_theme 2>/dev/null || print -r -- dark
}

t() {
    emulate -L zsh

    local requested=auto theme theme_file
    if [[ "${1:-}" == light || "${1:-}" == dark || "${1:-}" == auto ]]; then
        requested=$1
        shift
    fi

    if [[ "$requested" == auto ]]; then
        theme=$(_dotfiles_lite_tmux_detect_theme)
    else
        theme=$requested
    fi

    theme_file="$HOME/.tmux/themes/nord.conf"
    [[ "$theme" == light ]] && theme_file="$HOME/.tmux/themes/nord-light.conf"

    if [[ -r "$theme_file" ]]; then
        command env DOTFILES_LITE_TMUX_THEME="$theme" tmux \
            source-file "$theme_file" \; new-session -A -s 0 "$@"
    else
        command tmux new-session -A -s 0 "$@"
    fi
}
