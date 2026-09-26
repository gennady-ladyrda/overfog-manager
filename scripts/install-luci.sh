#!/bin/sh

set -eu

PREFIX=${PREFIX:-/usr}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$SCRIPT_DIR/luci-app-overfog-manager"
ALLOW_OVERWRITE=${OVERFOG_ALLOW_OVERWRITE:-0}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

copy_file() {
    source="$1"
    destination="$2"
    [ ! -e "$destination" ] || [ "$ALLOW_OVERWRITE" = "1" ] ||
        die "Refusing to overwrite existing file: $destination (set OVERFOG_ALLOW_OVERWRITE=1 explicitly)"
    mkdir -p "$(dirname -- "$destination")"
    sed 's/\r$//' "$source" > "$destination"
    chmod 0644 "$destination"
}

mkdir -p "$PREFIX/lib/lua/luci/controller" "$PREFIX/lib/lua/luci/view/overfog-manager"
copy_file "$APP_DIR/luasrc/controller/overfog-manager.lua" \
    "$PREFIX/lib/lua/luci/controller/overfog-manager.lua"
copy_file "$APP_DIR/luasrc/view/overfog-manager/overview.htm" \
    "$PREFIX/lib/lua/luci/view/overfog-manager/overview.htm"

echo "Installed read-only LuCI Overfog Manager page"
echo "Reload LuCI/uhttpd manually after reviewing the installation"
