#!/bin/sh

# Production paths are deliberately unchanged. Environment overrides are for
# isolated local tests only.
CONFIG="${OVERFOG_CONFIG:-/etc/sing-box/config.json}"
PROFILE_DIR="${OVERFOG_PROFILE_DIR:-/etc/sing-box/profiles}"
BACKUP_DIR="${OVERFOG_BACKUP_DIR:-/etc/sing-box/backups}"
ACTIVE_FILE="${OVERFOG_ACTIVE_FILE:-/etc/sing-box/active-profile}"

require_files() {
    command -v jq >/dev/null 2>&1 || die "jq not found"
    [ -r "$CONFIG" ] || die "Cannot read $CONFIG"
}

active_profile() {
    if [ -r "$ACTIVE_FILE" ]; then
        cat "$ACTIVE_FILE"
    else
        echo "-"
    fi
}
