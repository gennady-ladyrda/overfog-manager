# Overfog Manager — Agent Context

## Goal
Build `overfog-manager` for a GL.iNet GL-MT3000 (Beryl AX) running OpenWrt 25.12.5. It manages sing-box VLESS+REALITY Overfog profiles safely, eventually via both CLI and LuCI.

## Working principles
- Preserve the currently working router configuration; changes must be incremental and reversible.
- Never expose UUID, Reality public/private-related credentials, short IDs, or other secrets in logs/output.
- CLI and LuCI must use the same core switching/validation logic.
- A new profile must not become active until config validation and connectivity checks succeed.
- On failed switch, automatically restore the previous known-good configuration.
- Prefer atomic file replacement and explicit backups.
- Do not reintroduce Podkop.
- Keep router dependencies minimal. `jq`, `jsonfilter`, and full `sing-box` are already installed.

## Router environment
- Device: GL.iNet GL-MT3000 / Beryl AX
- OpenWrt: 25.12.5 r33051-f5dae5ece4
- Target: mediatek/filogic, aarch64_cortex-a53
- Kernel: 6.12.94
- Package manager: apk
- sing-box: 1.12.17, full build with gVisor/uTLS/etc.
- Current uplink: `sta1`, upstream subnet `192.168.8.0/24`, gateway `192.168.8.1`
- LAN: `br-lan`, `192.168.9.1/24`

## Known-good sing-box architecture
- Config: `/etc/sing-box/config.json`
- Service UCI: enabled, user root, config above, workdir `/usr/share/sing-box`
- TUN: `tun0`, `172.19.0.1/30`, MTU 1400
- `auto_route: true`, `strict_route: true`
- **Critical:** TUN stack must be `gvisor`; `system` caused TCP failures on this router.
- Main outbound tag: `overfog`, VLESS + REALITY + `xtls-rprx-vision`, uTLS fingerprint `qq`.
- Do not hardcode current UUID/short ID into repository context files.
- Current server at project bootstrap: `cdn-fl.ai-apiroute.cc:443`; credentials remain only on router/profile files.
- `direct` outbound also exists.
- `route.final = overfog`.

## Routing rules, in order
1. sniff: `http`, `tls`, `quic`, `bittorrent`, timeout 1s
2. domain suffix `.ru`, `.su`, `.by` -> direct
3. `geosite-category-ru` -> direct
4. `geoip-ru` -> direct
5. `17.0.0.0/8` -> direct
6. protocol `bittorrent` -> direct
7. protocol `dns` -> direct
8. `192.168.8.0/24` -> direct
9. final -> `overfog`

Remote rule sets:
- geoip-ru: `https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs`
- geosite-category-ru: `https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs`
- both use `download_detour: direct`

Persistent rule-set cache:
- `/etc/sing-box/cache.db`
- `experimental.cache_file.enabled = true`
- Cache behavior was tested by making remote URLs invalid; routing continued from cache.

## Firewall
A dedicated fw4 zone is bound directly to `tun0`:
- zone name: `singbox`
- input/output/forward ACCEPT
- forwarding: `lan -> singbox`
- no masquerade on singbox zone
This survived reboot and LAN clients route successfully through sing-box.

## Verified behavior
- Router and LAN traffic survive reboot.
- Foreign traffic (e.g. example.com) -> VLESS Overfog.
- `.ru` traffic (e.g. 2ip.ru) -> direct via domain suffix.
- Russian services on foreign hosting can be caught by `geosite-category-ru`.
- Russian IPs -> direct via geoip-ru.
- Apple `17.0.0.0/8` direct rule verified.
- BitTorrent direct rule installed and reported working.
- Overfog exit during setup was `178.17.60.19`; do not assume it is permanent.

## Existing manager state on router
Directories:
- `/etc/sing-box/profiles` mode 700
- `/etc/sing-box/backups` mode 700
- `/etc/sing-box/active-profile`

Initial profile:
- `/etc/sing-box/profiles/finland.json`, mode 600
- format:
  `{ "name": "finland", "country": "FI", "outbound": <complete overfog outbound object> }`
- The profile outbound was normalized with jq and confirmed identical to the active working outbound.
- `active-profile` contains `finland`.

Current `/usr/bin/overfogctl` prototype supports:
- `status`
- `list`
- `profile-create NAME [COUNTRY]`
- `test PROFILE`

`status` process detection was corrected for OpenWrt to use:
`pgrep -f '/usr/bin/sing-box run'`
rather than `pgrep -x sing-box`.

`test PROFILE`:
- validates profile structure
- creates a temporary full config by replacing only outbound with tag `overfog`
- verifies exactly one overfog outbound exists
- runs `sing-box check -c <temporary config>`
- removes temporary file
- does NOT modify or restart the active VPN
Positive and intentionally broken-profile tests passed.

## Planned CLI behavior
Target commands:
- `overfogctl status`
- `overfogctl list`
- `overfogctl profile-create NAME [COUNTRY]`
- `overfogctl import FILE`
- `overfogctl test PROFILE`
- `overfogctl switch PROFILE`
- `overfogctl rollback`
- `overfogctl doctor`

`switch PROFILE` must be transactional:
1. validate profile
2. generate temporary full config replacing only `overfog`
3. `sing-box check`
4. backup current known-good config
5. atomic install candidate config
6. restart sing-box
7. verify process
8. verify `tun0`
9. verify connectivity and VPN path/exit IP
10. only then update `active-profile`
11. on any post-install failure, restore previous config, restart, and verify recovery

`import FILE` target use case:
- input is an Overfog HAPP/Xray-style JSON, not native sing-box JSON
- extract VLESS/REALITY server, port, UUID, flow, SNI/serverName, uTLS fingerprint, Reality publicKey and shortId
- store complete normalized sing-box outbound profile
- avoid printing secrets
- support updated Overfog servers and switching country/provider profiles

`doctor` should be read-only and report at least:
- sing-box config valid
- process running
- tun0 present
- firewall singbox zone / LAN forwarding present
- cache file present
- active profile exists
- current config outbound matches active profile (or explicitly report drift)
- Overfog server resolution/TCP reachability as appropriate
- internet/VPN connectivity and exit IP

## Project direction
Create a normal Git project locally rather than continuing development with `vi` on router.
Suggested project name: `overfog-manager`.
CLI first, LuCI second. LuCI should be a thin UI over the same core operations.
Potential later UI: status, profile list, import, test/switch, rollback, diagnostics.
Do not implement independent switching logic in LuCI.

## Development workflow
- Develop locally (PyCharm/CLI), version in Git.
- Add deploy/install scripts for GL-MT3000.
- Keep fixtures sanitized; never commit real UUID/public key/short ID from the user's provider config.
- Before destructive/router-changing operations, validate and preserve a rollback path.
- Prefer tests around JSON transformation and state transitions before deploying.
