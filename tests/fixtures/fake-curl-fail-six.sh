#!/bin/sh

state_file="${FAKE_CURL_STATE:?}"
count=0
[ -r "$state_file" ] && count="$(cat "$state_file")"
count=$((count + 1))
printf '%s\n' "$count" > "$state_file"

# The first three watchdog cycles each make two curl calls.
[ "$count" -le 6 ] && exit 7

case "$*" in
    *api.ipify.org*) printf '%s' '203.0.113.7' ;;
esac
exit 0
