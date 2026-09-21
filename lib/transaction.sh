#!/bin/sh

# The helpers in this file do not restart services. They only manipulate
# explicitly supplied files and are intended to be called by switch/rollback.

backup_state() {
    config="$1"
    active_file="$2"
    backup_dir="$3"
    backup_id="$4"

    mkdir -p "$backup_dir" || return 1
    chmod 700 "$backup_dir" || return 1
    cp -p "$config" "$backup_dir/$backup_id.config.json" || return 1

    if [ -r "$active_file" ]; then
        cp -p "$active_file" "$backup_dir/$backup_id.active-profile" || return 1
    else
        rm -f "$backup_dir/$backup_id.active-profile" || return 1
    fi

    chmod 600 "$backup_dir/$backup_id.config.json" "$backup_dir/$backup_id.active-profile" 2>/dev/null || true
}

install_candidate_atomic() {
    candidate="$1"
    config="$2"
    config_dir=$(dirname -- "$config")
    staged="$config_dir/.config.json.$$"

    cp -p "$candidate" "$staged" || {
        rm -f "$staged"
        return 1
    }
    chmod 600 "$staged" || {
        rm -f "$staged"
        return 1
    }
    mv -f "$staged" "$config" || {
        rm -f "$staged"
        return 1
    }
}

write_active_atomic() {
    profile_name="$1"
    active_file="$2"
    active_dir=$(dirname -- "$active_file")
    staged="$active_dir/.active-profile.$$"

    printf '%s\n' "$profile_name" > "$staged" || {
        rm -f "$staged"
        return 1
    }
    chmod 600 "$staged" || {
        rm -f "$staged"
        return 1
    }
    mv -f "$staged" "$active_file" || {
        rm -f "$staged"
        return 1
    }
}

restore_backup() {
    backup_config="$1"
    backup_active="$2"
    config="$3"
    active_file="$4"

    install_candidate_atomic "$backup_config" "$config" || return 1

    if [ -r "$backup_active" ]; then
        install_candidate_atomic "$backup_active" "$active_file" || return 1
    else
        rm -f "$active_file" || return 1
    fi
}

find_latest_backup() {
    backup_dir="$1"
    latest=""

    for file in "$backup_dir"/*.config.json; do
        [ -f "$file" ] || continue
        case "$file" in
            *-before-rollback.config.json) continue ;;
        esac
        latest="$file"
    done

    [ -n "$latest" ] || return 1
    printf '%s\n' "$latest"
}
