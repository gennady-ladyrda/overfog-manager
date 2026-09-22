#!/bin/sh

set -u

ROOT=/tmp/overfog-manager-watchdog-failover
export PATH="$ROOT/bin:/usr/bin:/bin:/sbin:/usr/sbin"
export FAKE_CURL_STATE="$ROOT/curl-count"
export OVERFOG_WATCHDOG_CONFIG=1
export OVERFOG_WATCHDOG_ENABLED=1
export OVERFOG_WATCHDOG_INTERVAL=60
export OVERFOG_WATCHDOG_FAILURE_THRESHOLD=3
export OVERFOG_WATCHDOG_COOLDOWN=600
export OVERFOG_WATCHDOG_PROFILE_ORDER='Germaniya_2 Estoniya_1 finland'
export OVERFOG_WATCHDOG_STATE_DIR="$ROOT/state"
export OVERFOG_AUTOMATIC_BACKUP_DIR="$ROOT/backups"
export OVERFOG_BACKUP_DIR="$ROOT/backups"
export OVERFOG_OPERATION_LOCK_DIR="$ROOT/operation.lock"

rm -rf "$ROOT"
mkdir -p "$ROOT/bin"
cp /tmp/fake-curl-fail-six.sh "$ROOT/bin/curl"
chmod 0755 "$ROOT/bin/curl"

echo '--- WATCHDOG CYCLES ---'
/usr/bin/overfogctl watchdog once
/usr/bin/overfogctl watchdog once
/usr/bin/overfogctl watchdog once

echo '--- AFTER FAILOVER ---'
cat /etc/sing-box/active-profile
/usr/bin/overfogctl doctor --json

echo '--- ROLLBACK ---'
/usr/bin/overfogctl rollback

echo '--- AFTER RESTORE ---'
cat /etc/sing-box/active-profile
/usr/bin/overfogctl doctor --json

rm -rf "$ROOT"
