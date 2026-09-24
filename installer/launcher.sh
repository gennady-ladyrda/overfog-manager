#!/bin/sh

set -eu

self="$0"
payload_line="$(awk '/^__OVERFOG_PAYLOAD_BELOW__$/ { print NR + 1; exit }' "$self")"
[ -n "$payload_line" ] || {
    echo "ERROR: installer payload marker not found" >&2
    exit 1
}

tmp_dir="$(mktemp -d /tmp/overfog-manager-installer.XXXXXX)"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup 0 1 2 15

tail -n +"$payload_line" "$self" | tar -xzf - -C "$tmp_dir"
exec sh "$tmp_dir/installer/install.sh" "$@"

exit 0
__OVERFOG_PAYLOAD_BELOW__
