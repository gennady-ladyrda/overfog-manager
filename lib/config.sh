#!/bin/sh

count_overfog() {
    file="$1"
    jq '[.outbounds[] | select(.tag == "overfog")] | length' "$file"
}

canonicalize_static_routing() {
    canonicalize_input="$1"
    canonicalize_output="$2"

    # Profiles control only the overfog outbound. The TUN and split-routing
    # policy remains configuration-wide, so normalize it in the one candidate
    # generation path shared by test and switch.
    jq -e '
        def obsolete_dns_rule:
            (.protocol? == "dns" and .outbound? == "direct");
        def dns_port_rule:
            (.port? == 53
             and .network? == ["tcp", "udp"]
             and .outbound? == "direct");
        def diagnostic_2ip_rule:
            (.domain_suffix? == ["2ip.ru"] and .outbound? == "direct");

        if (.route | type) != "object" then
            error("route configuration is missing")
        elif (.route.rules | type) != "array" then
            error("route rules are missing")
        elif .route.auto_detect_interface != true then
            error("route.auto_detect_interface must be true")
        elif .route.final != "overfog" then
            error("route.final must be overfog")
        else
            .
            | .outbounds |= map(
                if .tag == "direct" then del(.bind_interface) else . end
              )
            | [.route.rules[]
               | select(obsolete_dns_rule | not)
               | select(dns_port_rule | not)
               | select(diagnostic_2ip_rule | not)] as $rules
            | ([$rules[] | select(.action? == "sniff")] | length) as $sniff_count
            | if $sniff_count != 1 then
                error("expected exactly one sniff route rule")
              else
                (reduce $rules[] as $rule
                  ([];
                   . + [$rule]
                     + (if $rule.action? == "sniff" then [{
                       port: 53,
                       network: ["tcp", "udp"],
                       outbound: "direct"
                     }] else [] end))) as $normalized_rules
                | .route.rules = $normalized_rules
              end
        end
    ' "$canonicalize_input" > "$canonicalize_output"
}

generate_candidate() {
    base_config="$1"
    profile="$2"
    output="$3"
    normalized_output="$output.canonical.$$"

    base_count="$(count_overfog "$base_config")" || return 1
    [ "$base_count" = "1" ] || return 1

    jq --slurpfile profile "$profile" '
        ($profile[0].outbound) as $new
        | .outbounds |= map(
            if .tag == "overfog"
            then $new
            else .
            end
        )
    ' "$base_config" > "$output" || return 1

    canonicalize_static_routing "$output" "$normalized_output" || {
        rm -f "$normalized_output"
        return 1
    }
    mv -f "$normalized_output" "$output" || {
        rm -f "$normalized_output"
        return 1
    }

    result_count="$(count_overfog "$output")" || return 1
    [ "$result_count" = "1" ]
}
