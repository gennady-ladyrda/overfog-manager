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

if "$ROOT/overfogctl" profile-create 'bad/name' >/dev/null 2>&1; then
    echo "profile name validation failed" >&2
    exit 1
fi

echo "POSIX CLI integration tests passed"
