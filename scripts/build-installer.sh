#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST=${DIST:-$ROOT/dist}
OUTPUT=${OUTPUT:-$DIST/overfog-manager-installer.run}
STAGE=${TMPDIR:-/tmp}/overfog-manager-installer-stage-$$

trap 'rm -rf "$STAGE"' 0 1 2 15
rm -rf "$STAGE"
mkdir -p "$STAGE/installer" "$DIST"

cp "$ROOT/installer/install.sh" "$STAGE/installer/install.sh"
cp "$ROOT/overfogctl" "$STAGE/overfogctl"
cp -R "$ROOT/lib" "$STAGE/lib"
cp -R "$ROOT/config" "$STAGE/config"
cp -R "$ROOT/etc" "$STAGE/etc"
cp -R "$ROOT/luci-app-overfog-manager" "$STAGE/luci-app-overfog-manager"

VERSION=${VERSION:-dev}
printf '{"name":"overfog-manager","version":"%s","format":1}\n' "$VERSION" \
    > "$STAGE/manifest.json"

(
    cd "$STAGE"
    sha256sum \
        manifest.json \
        installer/install.sh \
        overfogctl \
        lib/*.sh \
        config/overfog-manager \
        etc/init.d/overfog-manager-watchdog \
        luci-app-overfog-manager/luasrc/controller/overfog-manager.lua \
        luci-app-overfog-manager/luasrc/view/overfog-manager/overview.htm \
        > checksums.sha256
)

rm -f "$OUTPUT"
cat "$ROOT/installer/launcher.sh" > "$OUTPUT"
tar -czf - -C "$STAGE" \
    installer overfogctl lib config etc luci-app-overfog-manager manifest.json checksums.sha256 >> "$OUTPUT"
chmod 0755 "$OUTPUT"
sha256sum "$OUTPUT" > "$OUTPUT.sha256"
echo "Built $OUTPUT"
