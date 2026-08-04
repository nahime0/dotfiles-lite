#!/usr/bin/env bash

PACKAGE_LIST=()

read_package_file() {
    local file=$1
    local line

    [[ -f "$file" ]] || die "Package manifest not found: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        PACKAGE_LIST+=("$line")
    done < "$file"
}

run_as_root() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
            print_command "$@"
        else
            print_command sudo "$@"
        fi
        return 0
    fi

    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        die "Package installation needs root privileges or sudo. Re-run with --skip-packages if packages are managed separately."
    fi
}

install_optional_debian_packages() {
    local file=$1
    local package
    local -a available=()

    [[ -f "$file" ]] || return 0

    while IFS= read -r package || [[ -n "$package" ]]; do
        [[ -z "$package" || "$package" == \#* ]] && continue

        if [[ "${DRY_RUN:-false}" == true ]] || apt-cache show "$package" >/dev/null 2>&1; then
            available+=("$package")
        else
            warn "Optional package is unavailable and will be skipped: $package"
        fi
    done < "$file"

    if [[ ${#available[@]} -gt 0 ]]; then
        run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${available[@]}"
    fi
}

install_packages() {
    local profile=$1
    local with_optional=$2

    if [[ "${SKIP_PACKAGES:-false}" == true ]]; then
        info "Skipping package installation."
        return 0
    fi

    command_exists apt-get || die "This first release supports Debian/Ubuntu package installation only. Use --skip-packages on another distribution."

    PACKAGE_LIST=()
    read_package_file "$SCRIPT_DIR/packages/debian-minimal.txt"
    if [[ "$profile" == server ]]; then
        read_package_file "$SCRIPT_DIR/packages/debian-server.txt"
    fi

    info "Updating the APT package index."
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update

    info "Installing the $profile package profile."
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGE_LIST[@]}"

    if [[ "$with_optional" == true ]]; then
        info "Installing available optional server tools."
        install_optional_debian_packages "$SCRIPT_DIR/packages/debian-optional.txt"
    fi
}
