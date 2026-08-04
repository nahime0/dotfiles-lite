#!/usr/bin/env bash

# Safe, transactional dotfile linking. Existing targets are moved to the
# timestamped backup directory and restored if the installation later fails.

declare -a LINK_TARGETS=()
declare -a LINK_BACKUPS=()
BACKUP_COUNT=0
LINK_TRANSACTION_COMMITTED=false

link_dotfile() {
    local source=$1
    local target=$2
    local relative_target backup_target=''

    [[ -e "$source" ]] || die "Managed source does not exist: $source"

    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        info "Already linked: $target"
        return 0
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        relative_target=${target#"$HOME"/}
        backup_target="$BACKUP_DIR/$relative_target"
        info "Backing up $target to $backup_target"
        run mkdir -p "$(dirname "$backup_target")"
        run mv "$target" "$backup_target"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    fi

    info "Linking $target"
    run mkdir -p "$(dirname "$target")"

    if [[ "${DRY_RUN:-false}" != true ]]; then
        LINK_TARGETS+=("$target")
        LINK_BACKUPS+=("$backup_target")
    fi

    run ln -s "$source" "$target"
}

rollback_links() {
    local index target backup

    [[ "$LINK_TRANSACTION_COMMITTED" == false ]] || return 0
    [[ ${#LINK_TARGETS[@]} -gt 0 ]] || return 0

    warn "Installation failed; restoring the previous dotfiles."

    for ((index=${#LINK_TARGETS[@]} - 1; index >= 0; index--)); do
        target=${LINK_TARGETS[$index]}
        backup=${LINK_BACKUPS[$index]}

        if [[ -L "$target" ]]; then
            unlink "$target"
        elif [[ -e "$target" ]]; then
            warn "Cannot automatically remove unexpected replacement at $target"
            continue
        fi

        if [[ -n "$backup" && ( -e "$backup" || -L "$backup" ) ]]; then
            mkdir -p "$(dirname "$target")"
            mv "$backup" "$target"
        fi
    done
}

commit_link_transaction() {
    LINK_TRANSACTION_COMMITTED=true
}
