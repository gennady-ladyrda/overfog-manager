#!/bin/sh

set -eu

PREFIX=${PREFIX:-/usr/bin}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

install -d "$PREFIX"
install -d "$PREFIX/overfog-manager-lib"
install -m 0755 "$SCRIPT_DIR/overfogctl" "$PREFIX/overfogctl"
install -m 0644 "$SCRIPT_DIR/lib/paths.sh" "$PREFIX/overfog-manager-lib/paths.sh"
install -m 0644 "$SCRIPT_DIR/lib/profiles.sh" "$PREFIX/overfog-manager-lib/profiles.sh"
install -m 0644 "$SCRIPT_DIR/lib/config.sh" "$PREFIX/overfog-manager-lib/config.sh"
install -m 0644 "$SCRIPT_DIR/lib/transaction.sh" "$PREFIX/overfog-manager-lib/transaction.sh"
install -m 0644 "$SCRIPT_DIR/lib/checks.sh" "$PREFIX/overfog-manager-lib/checks.sh"
install -m 0644 "$SCRIPT_DIR/lib/service.sh" "$PREFIX/overfog-manager-lib/service.sh"
install -m 0644 "$SCRIPT_DIR/lib/import.sh" "$PREFIX/overfog-manager-lib/import.sh"
install -m 0644 "$SCRIPT_DIR/lib/watchdog.sh" "$PREFIX/overfog-manager-lib/watchdog.sh"
if [ -d "$SCRIPT_DIR/config" ]; then
    install -d /etc/config
    install -m 0644 "$SCRIPT_DIR/config/overfog-manager" /etc/config/overfog-manager
fi
if [ -f "$SCRIPT_DIR/etc/init.d/overfog-manager-watchdog" ]; then
    install -m 0755 "$SCRIPT_DIR/etc/init.d/overfog-manager-watchdog" /etc/init.d/overfog-manager-watchdog
fi
echo "Installed overfogctl to $PREFIX/overfogctl"
