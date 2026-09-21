#!/bin/sh

count_overfog() {
    file="$1"
    jq '[.outbounds[] | select(.tag == "overfog")] | length' "$file"
}

generate_candidate() {
    base_config="$1"
    profile="$2"
    output="$3"

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

    result_count="$(count_overfog "$output")" || return 1
    [ "$result_count" = "1" ]
}
