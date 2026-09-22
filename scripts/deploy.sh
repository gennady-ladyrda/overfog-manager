#!/bin/sh

set -eu

: "${ROUTER:?Set ROUTER to the router host, for example root@192.168.9.1}"
REMOTE_PATH=${REMOTE_PATH:-/usr/bin/overfogctl}
REMOTE_LIB_DIR=${REMOTE_LIB_DIR:-/usr/bin/overfog-manager-lib}
REMOTE_BACKUP_DIR=${REMOTE_BACKUP_DIR:-/etc/sing-box/backups/overfog-manager-deploy}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

ssh "$ROUTER" "mkdir -p '$REMOTE_BACKUP_DIR' '$REMOTE_LIB_DIR'"
ssh "$ROUTER" "if [ -e '$REMOTE_PATH' ]; then cp -p '$REMOTE_PATH' '$REMOTE_BACKUP_DIR/overfogctl.previous'; fi"
ssh "$ROUTER" "if [ -d '$REMOTE_LIB_DIR' ]; then cp -p '$REMOTE_LIB_DIR'/*.sh '$REMOTE_BACKUP_DIR/' 2>/dev/null || true; fi"
ssh "$ROUTER" "if [ -e /etc/init.d/overfog-manager-watchdog ]; then cp -p /etc/init.d/overfog-manager-watchdog '$REMOTE_BACKUP_DIR/overfog-manager-watchdog.previous'; fi"
scp "$SCRIPT_DIR/overfogctl" "$ROUTER:$REMOTE_PATH"
scp "$SCRIPT_DIR/lib/paths.sh" "$SCRIPT_DIR/lib/profiles.sh" "$SCRIPT_DIR/lib/config.sh" "$SCRIPT_DIR/lib/transaction.sh" "$SCRIPT_DIR/lib/checks.sh" "$SCRIPT_DIR/lib/service.sh" "$SCRIPT_DIR/lib/import.sh" "$SCRIPT_DIR/lib/watchdog.sh" "$ROUTER:$REMOTE_LIB_DIR/"
ssh "$ROUTER" "chmod 0755 '$REMOTE_PATH'"
ssh "$ROUTER" "chmod 0644 '$REMOTE_LIB_DIR/paths.sh' '$REMOTE_LIB_DIR/profiles.sh' '$REMOTE_LIB_DIR/config.sh' '$REMOTE_LIB_DIR/transaction.sh' '$REMOTE_LIB_DIR/checks.sh' '$REMOTE_LIB_DIR/service.sh' '$REMOTE_LIB_DIR/import.sh' '$REMOTE_LIB_DIR/watchdog.sh'"
if [ -f "$SCRIPT_DIR/config/overfog-manager" ]; then
    if ssh "$ROUTER" "test -e /etc/config/overfog-manager"; then
        echo "Preserving existing $ROUTER:/etc/config/overfog-manager"
    else
        scp "$SCRIPT_DIR/config/overfog-manager" "$ROUTER:/etc/config/overfog-manager"
    fi
fi
if [ -f "$SCRIPT_DIR/etc/init.d/overfog-manager-watchdog" ]; then
    scp "$SCRIPT_DIR/etc/init.d/overfog-manager-watchdog" "$ROUTER:/etc/init.d/overfog-manager-watchdog"
    ssh "$ROUTER" "chmod 0755 /etc/init.d/overfog-manager-watchdog"
fi
echo "Deployed overfogctl to $ROUTER:$REMOTE_PATH"
echo "Previous files backed up under $ROUTER:$REMOTE_BACKUP_DIR"
