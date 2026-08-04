# Keep a stable path to a forwarded SSH agent so long-lived tmux sessions can
# use the socket created by the latest SSH login. Private keys remain local.
if [[ -n "${SSH_CONNECTION:-}" && -n "${SSH_AUTH_SOCK:-}" ]]; then
    stable_agent_socket="$HOME/.ssh/ssh_auth_sock"

    if [[ -z "${TMUX:-}" && "$SSH_AUTH_SOCK" != "$stable_agent_socket" && -S "$SSH_AUTH_SOCK" ]]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ln -sfn "$SSH_AUTH_SOCK" "$stable_agent_socket"
    fi

    if [[ -S "$stable_agent_socket" ]]; then
        export SSH_AUTH_SOCK="$stable_agent_socket"
    fi

    unset stable_agent_socket
fi
