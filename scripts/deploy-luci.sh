#!/bin/sh

set -eu

: "${ROUTER:?Set ROUTER to the router host, for example root@192.168.9.1}"
REMOTE_BACKUP_DIR=${REMOTE_BACKUP_DIR:-/etc/sing-box/backups/overfog-manager-deploy}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$SCRIPT_DIR/luci-app-overfog-manager"

ssh "$ROUTER" "mkdir -p '$REMOTE_BACKUP_DIR/luci-controller' '$REMOTE_BACKUP_DIR/luci-view' /usr/lib/lua/luci/controller /usr/lib/lua/luci/view/overfog-manager"
ssh "$ROUTER" "if [ -e /usr/lib/lua/luci/controller/overfog-manager.lua ]; then cp -p /usr/lib/lua/luci/controller/overfog-manager.lua '$REMOTE_BACKUP_DIR/luci-controller/'; fi"
ssh "$ROUTER" "if [ -e /usr/lib/lua/luci/view/overfog-manager/overview.htm ]; then cp -p /usr/lib/lua/luci/view/overfog-manager/overview.htm '$REMOTE_BACKUP_DIR/luci-view/'; fi"
scp "$APP_DIR/luasrc/controller/overfog-manager.lua" "$ROUTER:/usr/lib/lua/luci/controller/overfog-manager.lua"
scp "$APP_DIR/luasrc/view/overfog-manager/overview.htm" "$ROUTER:/usr/lib/lua/luci/view/overfog-manager/overview.htm"
echo "Deployed read-only LuCI page to $ROUTER"
echo "Previous LuCI files backed up under $ROUTER:$REMOTE_BACKUP_DIR"
