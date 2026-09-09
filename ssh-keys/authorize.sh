#!/bin/bash
set -euo pipefail

public_key_directory="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
authorized_keys="${2:-$HOME/.ssh/authorized_keys}"

for public_key_file in "$public_key_directory"/*.pub; do
    [ -f "$public_key_file" ] || continue

    while IFS= read -r public_key || [ -n "$public_key" ]; do
        public_key="${public_key#"${public_key%%[![:space:]]*}"}"
        public_key="${public_key%"${public_key##*[![:space:]]}"}"
        case "$public_key" in
            ''|\#*) continue ;;
        esac

        mkdir -p "$(dirname "$authorized_keys")"
        chmod 700 "$(dirname "$authorized_keys")"
        (umask 077; touch "$authorized_keys")
        chmod 600 "$authorized_keys"

        if ! grep -Fqx -- "$public_key" "$authorized_keys"; then
            if [ -s "$authorized_keys" ] && [ -n "$(tail -c 1 "$authorized_keys")" ]; then
                printf '\n' >> "$authorized_keys"
            fi
            printf '%s\n' "$public_key" >> "$authorized_keys"
            echo "Authorized: $public_key_file -> $authorized_keys"
        fi
    done < "$public_key_file"
done
