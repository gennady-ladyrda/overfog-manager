#!/bin/sh

set -eu

PREFIX=${PREFIX:-/usr}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$SCRIPT_DIR/luci-app-overfog-manager"

install -d "$PREFIX/lib/lua/luci/controller"
install -d "$PREFIX/lib/lua/luci/view/overfog-manager"
install -m 0644 "$APP_DIR/luasrc/controller/overfog-manager.lua" \
    "$PREFIX/lib/lua/luci/controller/overfog-manager.lua"
install -m 0644 "$APP_DIR/luasrc/view/overfog-manager/overview.htm" \
    "$PREFIX/lib/lua/luci/view/overfog-manager/overview.htm"

echo "Installed read-only LuCI Overfog Manager page"
echo "Reload LuCI/uhttpd manually after reviewing the installation"
