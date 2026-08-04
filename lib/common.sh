#!/usr/bin/env bash

# Shared logging and execution helpers. This file is sourced by the installers.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLOR_BLUE=$'\033[34m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_RED=$'\033[31m'
    COLOR_RESET=$'\033[0m'
else
    COLOR_BLUE=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_RESET=''
fi

info() {
    printf '%s==>%s %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

success() {
    printf '%s==>%s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

warn() {
    printf '%swarning:%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*" >&2
}

die() {
    printf '%serror:%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

run() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_command "$@"
        return 0
    fi

    "$@"
}

confirm() {
    local prompt=${1:-Continue?}
    local reply

    if [[ "${ASSUME_YES:-false}" == true ]]; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        die "Interactive confirmation requires a terminal; pass --yes to continue non-interactively."
    fi

    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}
