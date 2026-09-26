#!/bin/sh

set -eu

PREFIX=${PREFIX:-/usr/bin}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALLOW_OVERWRITE=${OVERFOG_ALLOW_OVERWRITE:-0}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

copy_file() {
    source="$1"
    destination="$2"
    mode="$3"
    [ ! -e "$destination" ] || [ "$ALLOW_OVERWRITE" = "1" ] ||
        die "Refusing to overwrite existing file: $destination (set OVERFOG_ALLOW_OVERWRITE=1 explicitly)"
    mkdir -p "$(dirname -- "$destination")"
    sed 's/\r$//' "$source" > "$destination"
    chmod "$mode" "$destination"
}

mkdir -p "$PREFIX" "$PREFIX/overfog-manager-lib"
copy_file "$SCRIPT_DIR/overfogctl" "$PREFIX/overfogctl" 0755
for file in "$SCRIPT_DIR"/lib/*.sh; do
    copy_file "$file" "$PREFIX/overfog-manager-lib/$(basename "$file")" 0644
done
if [ -d "$SCRIPT_DIR/config" ]; then
    mkdir -p /etc/config
    if [ -e /etc/config/overfog-manager ] && [ "$ALLOW_OVERWRITE" != "1" ]; then
        echo "Preserving existing configuration: /etc/config/overfog-manager"
    else
        cp -p "$SCRIPT_DIR/config/overfog-manager" /etc/config/overfog-manager
    fi
fi
if [ -f "$SCRIPT_DIR/etc/init.d/overfog-manager-watchdog" ]; then
    copy_file "$SCRIPT_DIR/etc/init.d/overfog-manager-watchdog" /etc/init.d/overfog-manager-watchdog 0755
fi
echo "Installed overfogctl to $PREFIX/overfogctl"
