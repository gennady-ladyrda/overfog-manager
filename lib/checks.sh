#!/bin/sh

check_singbox_config() {
    config="$1"
    sing-box check -c "$config"
}

check_singbox_process() {
    pgrep -f '/usr/bin/sing-box run' >/dev/null 2>&1
}

check_tun_interface() {
    ip link show tun0 >/dev/null 2>&1
}

check_singbox_log_clean() {
    if logread | grep -Ei 'fatal|error' | tail -20 | grep . >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

check_basic_runtime() {
    check_singbox_process || return 1
    check_tun_interface || return 1
}

check_connectivity() {
    command -v curl >/dev/null 2>&1 || return 1
    curl -4 --http1.1 -k --connect-timeout 10 \
        https://example.com/ -o /dev/null >/dev/null 2>&1
}

get_exit_ip() {
    curl -4 -s --connect-timeout 10 https://api.ipify.org
}

check_exit_ip() {
    ip_address="$(get_exit_ip)" || return 1
    printf '%s\n' "$ip_address" | awk -F. '
        NF == 4 &&
        $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ &&
        $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ &&
        $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255
    '
}

check_firewall_singbox() {
    command -v uci >/dev/null 2>&1 || return 1
    zone_section="$(uci -q show firewall 2>/dev/null | awk -F= '
        $1 ~ /\.name$/ && $2 == "\047singbox\047" {
            sub(/\.name$/, "", $1)
            print $1
            exit
        }
    ')"
    [ -n "$zone_section" ] || return 1
    [ "$(uci -q get "$zone_section.device" 2>/dev/null)" = "tun0" ] || return 1
    [ "$(uci -q get "$zone_section.input" 2>/dev/null)" = "ACCEPT" ] || return 1
    [ "$(uci -q get "$zone_section.output" 2>/dev/null)" = "ACCEPT" ] || return 1
    [ "$(uci -q get "$zone_section.forward" 2>/dev/null)" = "ACCEPT" ]
}

check_firewall_forwarding() {
    command -v uci >/dev/null 2>&1 || return 1
    uci -q show firewall 2>/dev/null | awk -F= '
        $1 ~ /\.src$/ && $2 == "\047lan\047" {
            section=$1
            sub(/\.src$/, "", section)
            lan[section]=1
        }
        $1 ~ /\.dest$/ && $2 == "\047singbox\047" {
            section=$1
            sub(/\.dest$/, "", section)
            if (lan[section]) found=1
        }
        END { exit(found ? 0 : 1) }
    '
}

check_direct_probe() {
    url="$1"
    [ -n "$url" ] || return 0
    curl -4 --http1.1 -k --connect-timeout 10 \
        "$url" -o /dev/null >/dev/null 2>&1
}

check_optional_direct_probes() {
    check_direct_probe "${OVERFOG_DIRECT_PROBE_RU:-}" || return 1
    check_direct_probe "${OVERFOG_DIRECT_PROBE_BY:-}" || return 1
}

check_full_runtime() {
    check_basic_runtime || return 1
    check_connectivity || return 1
    check_exit_ip || return 1
    check_optional_direct_probes || return 1
}
