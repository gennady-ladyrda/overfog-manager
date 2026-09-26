#!/bin/sh

profile_summary() {
    file="$1"

    jq -r '
      [
        .name // "-",
        .country // "-",
        .outbound.server // "-",
        (.outbound.server_port // "-" | tostring)
      ] | @tsv
    ' "$file"
}

valid_profile_name() {
    name="$1"

    case "$name" in
        ""|.|..|*/*|*\\*|*..*|*[[:space:]]*) return 1 ;;
    esac
    return 0
}

validate_profile() {
    file="$1"

    jq -e '
        (.name | type == "string")
        and (.outbound | type == "object")
        and (.outbound.type == "vless")
        and (.outbound.tag == "overfog")
        and (.outbound.server | type == "string")
        and (.outbound.server_port | type == "number")
        and (.outbound.uuid | type == "string")
        and (.outbound.tls.enabled == true)
        and (.outbound.tls.reality.enabled == true)
        and (.outbound.tls.reality.public_key | type == "string")
        and (.outbound.tls.reality.short_id | type == "string")
    ' "$file" >/dev/null
}

profile_backup_references() {
    profile_name="$1"
    backup_dir="$2"
    found=1

    for active_file in "$backup_dir"/*.active-profile; do
        [ -f "$active_file" ] || continue
        saved_name="$(tr -d '\r\n' < "$active_file")"
        [ "$saved_name" = "$profile_name" ] || continue
        printf '%s\n' "${active_file%.active-profile}"
        found=0
    done

    return "$found"
}

delete_profile_backup_references() {
    profile_name="$1"
    backup_dir="$2"

    profile_backup_references "$profile_name" "$backup_dir" | while IFS= read -r base; do
        rm -f "$base.config.json" "$base.active-profile" "$base.metadata.json" || exit 1
    done
}
