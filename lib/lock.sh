#!/bin/sh

OPERATION_LOCK_DIR="${OVERFOG_OPERATION_LOCK_DIR:-/var/run/overfog-manager-operation.lock}"

acquire_operation_lock() {
    mkdir "$OPERATION_LOCK_DIR" 2>/dev/null || return 1
    printf '%s\n' "$$" > "$OPERATION_LOCK_DIR/pid"
}

release_operation_lock() {
    rm -f "$OPERATION_LOCK_DIR/pid"
    rmdir "$OPERATION_LOCK_DIR" 2>/dev/null || true
}
