#!/bin/sh

restart_singbox() {
    /etc/init.d/sing-box restart >/dev/null 2>&1
}

wait_for_basic_runtime() {
    attempts="${1:-10}"
    delay="${2:-1}"

    while [ "$attempts" -gt 0 ]; do
        if check_basic_runtime; then
            return 0
        fi
        attempts=$((attempts - 1))
        [ "$attempts" -gt 0 ] || break
        sleep "$delay"
    done

    return 1
}

wait_for_full_runtime() {
    attempts="${1:-10}"
    delay="${2:-1}"

    while [ "$attempts" -gt 0 ]; do
        if check_full_runtime; then
            return 0
        fi
        attempts=$((attempts - 1))
        [ "$attempts" -gt 0 ] || break
        sleep "$delay"
    done

    return 1
}
