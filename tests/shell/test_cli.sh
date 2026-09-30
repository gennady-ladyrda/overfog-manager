#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/overfog-tests.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' 0 1 2 15

command -v jq >/dev/null 2>&1 || {
    echo "SKIP: jq is not available"
    exit 0
}

FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/sing-box" <<'EOF'
#!/bin/sh
[ "${1:-}" = "check" ] && exit 0
exit 1
EOF
chmod 0755 "$FAKE_BIN/sing-box"

CONFIG="$TMP_ROOT/config.json"
PROFILES="$TMP_ROOT/profiles"
ACTIVE="$TMP_ROOT/active-profile"
cp "$ROOT/tests/fixtures/config.base.sanitized.json" "$CONFIG"

export OVERFOG_CONFIG="$CONFIG"
export OVERFOG_PROFILE_DIR="$PROFILES"
export OVERFOG_ACTIVE_FILE="$ACTIVE"
export OVERFOG_OPERATION_LOCK_DIR="$TMP_ROOT/operation.lock"
export PATH="$FAKE_BIN:$PATH"

"$ROOT/overfogctl" profile-create finland FI >/dev/null
test -r "$PROFILES/finland.json"
"$ROOT/overfogctl" test finland >/dev/null
"$ROOT/overfogctl" list | grep -F 'finland' >/dev/null

# Candidate generation removes only temporary diagnostic routing and uplink
# binding while retaining the established split-routing policy.
LEGACY_CONFIG="$TMP_ROOT/legacy-config.json"
CANDIDATE="$TMP_ROOT/candidate.json"
jq '
    .outbounds |= map(if .tag == "direct" then .bind_interface = "sta1" else . end)
    | .route.rules |= (
        . + [
          {"protocol": "dns", "outbound": "direct"},
          {"domain_suffix": ["2ip.ru"], "outbound": "direct"}
        ]
      )
  ' "$CONFIG" > "$LEGACY_CONFIG"

# shellcheck disable=SC1090
. "$ROOT/lib/config.sh"
generate_candidate "$LEGACY_CONFIG" "$PROFILES/finland.json" "$CANDIDATE"

jq -e '
    .route.rules[0].action == "sniff"
    and .route.rules[1] == {"port": 53, "network": ["tcp", "udp"], "outbound": "direct"}
    and ([.route.rules[] | select(.protocol? == "dns" and .outbound? == "direct")] | length) == 0
    and ([.route.rules[] | select((.domain_suffix? // []) | index("2ip.ru"))] | length) == 0
    and (.route.rules[2].domain_suffix == [".ru", ".su", ".by"])
    and (.route.rules[3].rule_set == ["geosite-category-ru"])
    and (.route.rules[4].rule_set == ["geoip-ru"])
    and (.outbounds[] | select(.tag == "direct") | has("bind_interface") | not)
    and .route.auto_detect_interface == true
    and .route.final == "overfog"
    and (.inbounds[] | select(.type == "tun") | .stack == "gvisor")
    and .log.level == "info"
  ' "$CANDIDATE" >/dev/null

assert_candidate_failure() {
    invalid_config="$1"
    expected_error="$2"
    error_file="$TMP_ROOT/candidate-error.txt"

    if generate_candidate "$invalid_config" "$PROFILES/finland.json" "$CANDIDATE" \
        2>"$error_file"; then
        echo "candidate generation unexpectedly succeeded: $expected_error" >&2
        exit 1
    fi
    grep -F "$expected_error" "$error_file" >/dev/null
}

INVALID_AUTO_FALSE="$TMP_ROOT/invalid-auto-false.json"
INVALID_AUTO_MISSING="$TMP_ROOT/invalid-auto-missing.json"
INVALID_FINAL_VALUE="$TMP_ROOT/invalid-final-value.json"
INVALID_FINAL_MISSING="$TMP_ROOT/invalid-final-missing.json"
jq '.route.auto_detect_interface = false' "$CONFIG" > "$INVALID_AUTO_FALSE"
jq 'del(.route.auto_detect_interface)' "$CONFIG" > "$INVALID_AUTO_MISSING"
jq '.route.final = "direct"' "$CONFIG" > "$INVALID_FINAL_VALUE"
jq 'del(.route.final)' "$CONFIG" > "$INVALID_FINAL_MISSING"

assert_candidate_failure "$INVALID_AUTO_FALSE" "route.auto_detect_interface must be true"
assert_candidate_failure "$INVALID_AUTO_MISSING" "route.auto_detect_interface must be true"
assert_candidate_failure "$INVALID_FINAL_VALUE" "route.final must be overfog"
assert_candidate_failure "$INVALID_FINAL_MISSING" "route.final must be overfog"

if "$ROOT/overfogctl" profile-create 'bad/name' >/dev/null 2>&1; then
    echo "profile name validation failed" >&2
    exit 1
fi

echo "POSIX CLI integration tests passed"
