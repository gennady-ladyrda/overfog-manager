#!/bin/sh

set -eu

PAYLOAD_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BACKUP_ROOT=${OVERFOG_DEPLOY_BACKUP_DIR:-/etc/sing-box/backups/overfog-manager-deploy}
BACKUP_ID=$(date +%Y%m%d-%H%M%S)-installer-$$
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
CHECK_ONLY=0
PRUNE_BACKUPS=0

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for argument in "$@"; do
    case "$argument" in
        --check) CHECK_ONLY=1 ;;
        --prune-backups) PRUNE_BACKUPS=1 ;;
        --help|-h)
            echo "Usage: installer.run [--check] [--prune-backups]"
            echo "  --check  show inventory without changing files"
            echo "  --prune-backups  retain only the newest three installer backups"
            exit 0
            ;;
        *) die "Unknown option: $argument" ;;
    esac
done

read_choice() {
    prompt="$1"
    while :; do
        printf '%s' "$prompt" >&2
        IFS= read -r answer < /dev/tty || die "Interactive terminal is required"
        case "$answer" in
            k|K|u|U|s|S|a|A|i|I) printf '%s\n' "$answer"; return 0 ;;
            *) echo "Choose k, u, s, a, or i." >&2 ;;
        esac
    done
}

backup_file() {
    source="$1"
    relative="$2"
    [ -e "$source" ] || return 0
    destination="$BACKUP_DIR/$relative"
    mkdir -p "$(dirname -- "$destination")"
    cp -p "$source" "$destination"
}

install_file() {
    source="$1"
    destination="$2"
    mode="$3"
    mkdir -p "$(dirname -- "$destination")"
    case "$destination" in
        /usr/bin/overfogctl|/usr/bin/overfog-manager-lib/*.sh|/etc/init.d/*)
            staged="$destination.$$"
            sed 's/\r$//' "$source" > "$staged"
            chmod "$mode" "$staged"
            mv -f "$staged" "$destination"
            ;;
        *)
            cp -p "$source" "$destination"
            chmod "$mode" "$destination"
            ;;
    esac
}

group_exists() {
    group="$1"
    case "$group" in
        cli)
            [ -e /usr/bin/overfogctl ] || [ -d /usr/bin/overfog-manager-lib ] ;;
        luci)
            [ -e /usr/lib/lua/luci/controller/overfog-manager.lua ] ||
            [ -e /usr/lib/lua/luci/view/overfog-manager/overview.htm ] ;;
        watchdog)
            [ -e /etc/init.d/overfog-manager-watchdog ] ;;
        configuration)
            [ -e /etc/config/overfog-manager ] ;;
        *) return 1 ;;
    esac
}

show_inventory() {
    echo "Overfog Manager installer"
    echo "========================="
    echo "Router: $(ubus call system board 2>/dev/null | jsonfilter -e '@.model' 2>/dev/null || echo unknown)"
    echo "OpenWrt: $(ubus call system board 2>/dev/null | jsonfilter -e '@.release.version' 2>/dev/null || echo unknown)"
    echo
    for group in cli luci watchdog configuration; do
        if group_exists "$group"; then
            printf '%-14s: installed\n' "$group"
        else
            printf '%-14s: not installed\n' "$group"
        fi
    done
    echo "sing-box config: $([ -e /etc/sing-box/config.json ] && echo present || echo missing)"
    echo "active profile : $([ -r /etc/sing-box/active-profile ] && cat /etc/sing-box/active-profile || echo unknown)"
    echo
}

install_cli() {
    install_file "$PAYLOAD_ROOT/overfogctl" /usr/bin/overfogctl 0755
    for file in "$PAYLOAD_ROOT"/lib/*.sh; do
        install_file "$file" "/usr/bin/overfog-manager-lib/$(basename "$file")" 0644
    done
}

install_luci() {
    install_file "$PAYLOAD_ROOT/luci-app-overfog-manager/luasrc/controller/overfog-manager.lua" \
        /usr/lib/lua/luci/controller/overfog-manager.lua 0644
    install_file "$PAYLOAD_ROOT/luci-app-overfog-manager/luasrc/view/overfog-manager/overview.htm" \
        /usr/lib/lua/luci/view/overfog-manager/overview.htm 0644
}

install_watchdog() {
    install_file "$PAYLOAD_ROOT/etc/init.d/overfog-manager-watchdog" \
        /etc/init.d/overfog-manager-watchdog 0755
}

install_configuration() {
    install_file "$PAYLOAD_ROOT/config/overfog-manager" \
        /etc/config/overfog-manager 0644
}

prune_deployment_backups() {
    remaining=0
    for directory in "$BACKUP_ROOT"/*-installer-*; do
        [ -d "$directory" ] || continue
        remaining=$((remaining + 1))
    done
    [ "$remaining" -gt 3 ] || return 0

    remove_count=$((remaining - 3))
    for directory in "$BACKUP_ROOT"/*-installer-*; do
        [ -d "$directory" ] || continue
        [ "$remove_count" -gt 0 ] || break
        echo "Removing old deployment backup: $directory"
        rm -rf "$directory"
        remove_count=$((remove_count - 1))
    done
}

apply_group() {
    group="$1"
    choice="$2"
    [ "$choice" = "k" ] || [ "$choice" = "K" ] || [ "$choice" = "s" ] || [ "$choice" = "S" ] || {
        mkdir -p "$BACKUP_DIR"
        case "$group" in
            cli)
                backup_file /usr/bin/overfogctl overfogctl
                for file in /usr/bin/overfog-manager-lib/*.sh; do
                    [ -e "$file" ] || continue
                    backup_file "$file" "lib/$(basename "$file")"
                done
                install_cli
                ;;
            luci)
                backup_file /usr/lib/lua/luci/controller/overfog-manager.lua luci/controller/overfog-manager.lua
                backup_file /usr/lib/lua/luci/view/overfog-manager/overview.htm luci/view/overfog-manager/overview.htm
                install_luci
                ;;
            watchdog)
                backup_file /etc/init.d/overfog-manager-watchdog watchdog/overfog-manager-watchdog
                install_watchdog
                ;;
            configuration)
                backup_file /etc/config/overfog-manager configuration/overfog-manager
                install_configuration
                ;;
        esac
        echo "Updated group: $group"
    }
}

[ "$(id -u)" = "0" ] || die "Run installer as root"
command -v ubus >/dev/null 2>&1 || die "OpenWrt ubus is required"
for required in cp mkdir tar chmod sed sha256sum; do
    command -v "$required" >/dev/null 2>&1 || die "$required not found"
done

[ -r "$PAYLOAD_ROOT/manifest.json" ] || die "Bundle manifest is missing"
[ -r "$PAYLOAD_ROOT/checksums.sha256" ] || die "Bundle checksums are missing"
(cd "$PAYLOAD_ROOT" && sha256sum -c checksums.sha256 >/dev/null) ||
    die "Bundle checksum verification failed"

show_inventory
echo "No existing file or sing-box configuration will be overwritten silently."
echo

if [ "$CHECK_ONLY" -eq 1 ]; then
    echo "Check-only mode: no files changed."
    exit 0
fi

for group in cli luci watchdog configuration; do
    if group_exists "$group"; then
        choice="$(read_choice "$group exists: [k]eep [u]pdate [s]kip [a]bort: ")"
    else
        choice="$(read_choice "$group is absent: [i]nstall [s]kip [a]bort: ")"
    fi
    case "$choice" in
        a|A) die "Installation aborted by user" ;;
        i|I|u|U|k|K|s|S) apply_group "$group" "$choice" ;;
    esac
done

if [ -d "$BACKUP_DIR" ]; then
    cat > "$BACKUP_DIR/manifest.txt" <<EOF2
installer_backup=$BACKUP_ID
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF2
    chmod 600 "$BACKUP_DIR/manifest.txt"
    echo "Deployment backup: $BACKUP_DIR"
fi

if [ "$PRUNE_BACKUPS" -eq 1 ]; then
    prune_deployment_backups
fi

echo "Installation choices completed. sing-box configuration was not changed."
