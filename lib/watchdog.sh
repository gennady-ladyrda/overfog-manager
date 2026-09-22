#!/bin/sh

# Watchdog configuration and state helpers. The monitoring loop is deliberately
# kept separate from these helpers so configuration can be inspected safely.

WATCHDOG_CONFIG="${OVERFOG_WATCHDOG_CONFIG:-/etc/config/overfog-manager}"
WATCHDOG_STATE_DIR="${OVERFOG_WATCHDOG_STATE_DIR:-/var/run/overfog-manager}"
WATCHDOG_STATE_FILE="$WATCHDOG_STATE_DIR/state.json"
WATCHDOG_LOCK_DIR="${OVERFOG_WATCHDOG_LOCK_DIR:-/var/run/overfog-manager.lock}"
WATCHDOG_AUTOMATIC_BACKUP_DIR="${OVERFOG_AUTOMATIC_BACKUP_DIR:-/etc/sing-box/backups/automatic}"

watchdog_uci_get() {
    key="$1"
    if [ -n "${OVERFOG_WATCHDOG_CONFIG:-}" ]; then
        case "$key" in
            enabled) printf '%s\n' "${OVERFOG_WATCHDOG_ENABLED:-0}" ;;
            interval) printf '%s\n' "${OVERFOG_WATCHDOG_INTERVAL:-60}" ;;
            failure_threshold) printf '%s\n' "${OVERFOG_WATCHDOG_FAILURE_THRESHOLD:-3}" ;;
            cooldown) printf '%s\n' "${OVERFOG_WATCHDOG_COOLDOWN:-600}" ;;
            profile_order) printf '%s\n' "${OVERFOG_WATCHDOG_PROFILE_ORDER:-}" ;;
            *) return 1 ;;
        esac
        return 0
    fi
    command -v uci >/dev/null 2>&1 || return 1
    uci -q get "overfog-manager.main.$key" 2>/dev/null
}

watchdog_value() {
    key="$1"
    fallback="$2"
    value="$(watchdog_uci_get "$key" 2>/dev/null || true)"
    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

watchdog_enabled() {
    [ "$(watchdog_value enabled 0)" = "1" ]
}

watchdog_interval() {
    watchdog_value interval 60
}

watchdog_failure_threshold() {
    watchdog_value failure_threshold 3
}

watchdog_cooldown() {
    watchdog_value cooldown 600
}

watchdog_profile_order() {
    watchdog_value profile_order ""
}

watchdog_positive_integer() {
    value="$1"
    case "$value" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$value" -gt 0 ]
}

watchdog_validate_config() {
    watchdog_positive_integer "$(watchdog_interval)" || return 1
    watchdog_positive_integer "$(watchdog_failure_threshold)" || return 1
    watchdog_positive_integer "$(watchdog_cooldown)" || return 1

    order="$(watchdog_profile_order)"
    [ -n "$order" ] || return 1
    for profile in $order; do
        valid_profile_name "$profile" || return 1
    done
}

watchdog_state_init() {
    mkdir -p "$WATCHDOG_STATE_DIR" || return 1
    chmod 700 "$WATCHDOG_STATE_DIR" || return 1
    if [ ! -r "$WATCHDOG_STATE_FILE" ]; then
        watchdog_state_write "" 0 '{}'
    fi
}

watchdog_state_write() {
    profile="$1"
    failures="$2"
    cooldowns="$3"
    mkdir -p "$WATCHDOG_STATE_DIR" || return 1
    chmod 700 "$WATCHDOG_STATE_DIR" || return 1
    staged="$WATCHDOG_STATE_DIR/.state.json.$$"
    jq -n --arg profile "$profile" --argjson failures "$failures" \
        --argjson cooldowns "$cooldowns" \
        '{active_profile:$profile, consecutive_failures:$failures, cooldown:$cooldowns}' \
        > "$staged" || {
        rm -f "$staged"
        return 1
    }
    chmod 600 "$staged" || {
        rm -f "$staged"
        return 1
    }
    mv -f "$staged" "$WATCHDOG_STATE_FILE"
}

watchdog_state_valid() {
    [ -r "$WATCHDOG_STATE_FILE" ] || return 1
    jq -e '
        (.active_profile | type == "string") and
        (.consecutive_failures | type == "number") and
        (.cooldown | type == "object")
    ' "$WATCHDOG_STATE_FILE" >/dev/null 2>&1
}

watchdog_state_profile() {
    watchdog_state_valid || return 1
    jq -r '.active_profile' "$WATCHDOG_STATE_FILE"
}

watchdog_state_failures() {
    watchdog_state_valid || return 1
    jq -r '.consecutive_failures' "$WATCHDOG_STATE_FILE"
}

watchdog_state_cooldowns() {
    watchdog_state_valid || return 1
    jq -c '.cooldown' "$WATCHDOG_STATE_FILE"
}

watchdog_now() {
    date +%s
}

watchdog_candidate_available() {
    profile="$1"
    cooldowns="$2"
    now="$3"
    jq -e --arg profile "$profile" --argjson now "$now" \
        '((.[$profile] // 0) | tonumber) <= $now' \
        <<EOF >/dev/null 2>&1
$cooldowns
EOF
}

watchdog_cooldown_profile() {
    cooldowns="$1"
    profile="$2"
    until="$3"
    jq -c --arg profile "$profile" --argjson until "$until" \
        '. + {($profile): $until}' <<EOF
$cooldowns
EOF
}

watchdog_clear_cooldown() {
    cooldowns="$1"
    profile="$2"
    jq -c --arg profile "$profile" 'del(.[$profile])' <<EOF
$cooldowns
EOF
}

watchdog_prune_automatic_backups() {
    directory="$WATCHDOG_AUTOMATIC_BACKUP_DIR"
    [ -d "$directory" ] || return 0

    latest=""
    for file in "$directory"/*.config.json; do
        [ -f "$file" ] || continue
        case "$file" in
            *-before-rollback.config.json) continue ;;
        esac
        latest="$file"
    done
    [ -n "$latest" ] || return 0

    for file in "$directory"/*.config.json; do
        [ -f "$file" ] || continue
        [ "$file" = "$latest" ] && continue
        base="${file%.config.json}"
        rm -f "$file" "$base.active-profile" "$base.metadata.json"
    done
}
