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

watchdog_configure() {
    enabled="$1"
    interval="$2"
    threshold="$3"
    cooldown="$4"

    case "$enabled" in 0|1) ;; *) return 1 ;; esac
    watchdog_positive_integer "$interval" || return 1
    watchdog_positive_integer "$threshold" || return 1
    watchdog_positive_integer "$cooldown" || return 1
    [ -n "${OVERFOG_WATCHDOG_CONFIG:-}" ] && return 1
    command -v uci >/dev/null 2>&1 || return 1
    uci -q set "overfog-manager.main.enabled=$enabled" || return 1
    uci -q set "overfog-manager.main.interval=$interval" || return 1
    uci -q set "overfog-manager.main.failure_threshold=$threshold" || return 1
    uci -q set "overfog-manager.main.cooldown=$cooldown" || return 1
    uci -q commit overfog-manager || return 1
}

watchdog_profile_order() {
    watchdog_value profile_order ""
}

watchdog_profile_order_set() {
    order="$1"

    for profile in $order; do
        valid_profile_name "$profile" || return 1
        [ -r "$PROFILE_DIR/$profile.json" ] || return 1
    done

    previous=""
    for profile in $order; do
        case " $previous " in
            *" $profile "*) return 1 ;;
        esac
        previous="$previous $profile"
    done

    # Test fixtures use environment-backed configuration and must not mutate
    # the host. Production changes are committed atomically through UCI.
    [ -n "${OVERFOG_WATCHDOG_CONFIG:-}" ] && return 0
    command -v uci >/dev/null 2>&1 || return 1
    uci -q delete overfog-manager.main.profile_order || true
    for profile in $order; do
        uci -q add_list overfog-manager.main.profile_order="$profile" || return 1
    done
    uci -q commit overfog-manager || return 1
}

watchdog_profile_order_add() {
    profile="$1"
    valid_profile_name "$profile" || return 1
    [ -r "$PROFILE_DIR/$profile.json" ] || return 1
    order="$(watchdog_profile_order)"
    for existing in $order; do
        [ "$existing" = "$profile" ] && return 0
    done
    if [ -n "$order" ]; then
        order="$order $profile"
    else
        order="$profile"
    fi
    watchdog_profile_order_set "$order"
}

watchdog_profile_order_remove() {
    profile="$1"
    order=""
    for existing in $(watchdog_profile_order); do
        [ "$existing" = "$profile" ] && continue
        if [ -n "$order" ]; then order="$order $existing"; else order="$existing"; fi
    done
    watchdog_profile_order_set "$order"
}

watchdog_profile_order_move() {
    profile="$1"
    direction="$2"
    set -- $(watchdog_profile_order)
    count=$#
    [ "$count" -gt 0 ] || return 1

    position=0
    index=1
    for existing in "$@"; do
        if [ "$existing" = "$profile" ]; then position=$index; break; fi
        index=$((index + 1))
    done
    [ "$position" -gt 0 ] || return 1
    case "$direction" in
        up) [ "$position" -gt 1 ] || return 0; target=$((position - 1)) ;;
        down) [ "$position" -lt "$count" ] || return 0; target=$((position + 1)) ;;
        *) return 1 ;;
    esac

    result=""
    index=1
    inserted=0
    for existing in "$@"; do
        [ "$existing" = "$profile" ] && continue
        if [ "$index" -eq "$target" ]; then
            if [ -n "$result" ]; then result="$result $profile"; else result="$profile"; fi
            inserted=1
        fi
        if [ -n "$result" ]; then result="$result $existing"; else result="$existing"; fi
        index=$((index + 1))
    done
    [ "$inserted" -eq 1 ] || {
        if [ -n "$result" ]; then result="$result $profile"; else result="$profile"; fi
    }
    watchdog_profile_order_set "$result"
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
    for profile in $order; do
        valid_profile_name "$profile" || return 1
        [ -r "$PROFILE_DIR/$profile.json" ] || return 1
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
