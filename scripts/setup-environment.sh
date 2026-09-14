#!/bin/sh
set -eu

required_commands='make cc sml poly mlton'
missing_packages=''

add_package() {
    case " $missing_packages " in
        *" $1 "*) ;;
        *) missing_packages="$missing_packages $1" ;;
    esac
}

for command_name in $required_commands; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        case "$command_name" in
            make) add_package make ;;
            cc) add_package build-essential ;;
            sml) add_package smlnj ;;
            poly) add_package polyml ;;
            mlton) add_package mlton ;;
        esac
    fi
done

if [ -z "$missing_packages" ]; then
    printf '%s\n' 'Rune build environment is already complete.'
else
    if [ ! -r /etc/os-release ]; then
        printf '%s\n' 'error: /etc/os-release is unavailable; Debian/Ubuntu detection is required.' >&2
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        debian|ubuntu) ;;
        *)
            printf 'error: unsupported distribution: %s (Debian/Ubuntu required)\n' "${PRETTY_NAME:-unknown}" >&2
            exit 1
            ;;
    esac

    if ! command -v apt-get >/dev/null 2>&1; then
        printf '%s\n' 'error: apt-get is required to install the Rune build environment.' >&2
        exit 1
    fi

    if [ "$(id -u)" -eq 0 ]; then
        apt='apt-get'
    elif command -v sudo >/dev/null 2>&1; then
        apt='sudo apt-get'
    else
        printf '%s\n' 'error: missing tools require apt-get with root privileges or sudo.' >&2
        exit 1
    fi

    printf 'Installing missing packages:%s\n' "$missing_packages"
    $apt update
    # shellcheck disable=SC2086
    $apt install -y $missing_packages
fi

for command_name in $required_commands; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'error: required command remains unavailable after setup: %s\n' "$command_name" >&2
        exit 1
    fi
done

printf '%s\n' 'Rune build environment is ready.'
