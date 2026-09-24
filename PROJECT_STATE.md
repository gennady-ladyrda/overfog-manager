# Overfog Manager — Current State / Handoff

## Current status

The router VPN configuration is healthy and reboot-tested. The repository now
contains the router-derived POSIX shell CLI and shared shell libraries. The
profiles `Germaniya_2` and `Estoniya_1` were switched successfully on the
router on 2026-09-22. A clean `switch → rollback` test completed successfully.
The latest router read-only check reports `Estoniya_1` active and matching the
active config.

The confirmed watchdog priority order is `Germaniya_2 Estoniya_1 finland`.
The legacy profile `🇩🇪_Германия_№2` is intentionally excluded.

The current CLI commands are:

- `status`
- `list [--json]`
- `profile-create NAME [COUNTRY]`
- `test PROFILE`
- `switch PROFILE`
- `rollback`
- `doctor`
- `import FILE [--country COUNTRY]`

## Implemented repository pieces

- `overfogctl` — entry point and command dispatch;
- `lib/paths.sh` — production paths plus isolated test overrides;
- `lib/profiles.sh` — profile validation and summaries;
- `lib/config.sh` — candidate config generation and exactly-one `overfog` check;
- `lib/checks.sh` — sing-box, process, tun0, log, and curl checks;
- `lib/service.sh` — confirmed restart command and runtime waits;
- `lib/transaction.sh` — backups, atomic installation, active-profile write, restore;
- `lib/import.sh` — HAPP/Xray VLESS+REALITY normalization and `remarks` name
  derivation;
- `scripts/install.sh` and `scripts/deploy.sh` — CLI plus library deployment;
- sanitized native, profile, and HAPP/Xray fixtures;
- LuCI profile list backed by secret-safe `list --json` output;
- Python repository tests.

`switch` validates and checks a candidate, backs up the current state, installs
atomically, runs `/etc/init.d/sing-box restart`, checks process/tun/curl,
and restores the previous state on failure. Optional direct probes use
`OVERFOG_DIRECT_PROBE_RU` and `OVERFOG_DIRECT_PROBE_BY`.

`rollback` selects the latest managed switch backup, saves the current state
as a separate pre-rollback backup, restores atomically, restarts, and verifies
runtime. `doctor` is read-only and reports configuration, process, tun0, log,
cache, active-profile drift, external connectivity, exit-IP format, the
singbox zone on tun0, and LAN-to-singbox forwarding. Exit IP is observed via
api.ipify and is not compared with the VLESS server address. Historical
`fatal/error` log matches are informational and do not block switching.

## Verification status

Local Python tests: 7 passed. POSIX shell execution tests are skipped on the
current Windows environment because `sh` is unavailable. `jq`, `sing-box`,
OpenWrt service commands and router `switch` have not been exercised. The
read-only CLI and LuCI files were deployed with backups; the LuCI page itself
was opened and verified in the browser.

The supplied curl probe verifies external reachability. The api.ipify probe
observes and validates the returned IPv4 format; it does not assert a fixed
value because the exit IP is dynamic.

## Remaining work, in order

1. Run the POSIX shell integration harness in Linux/OpenWrt-like CI.
2. Refresh LuCI and confirm the secret-safe profile list is visible; retrying
   paste of the existing source should report `Source: paste` and the expected
   duplicate-profile message.
3. Re-import the HAPP/Xray source only if a new profile is desired; the current
   `Germaniya_2` import and test are already verified.
4. Keep the verified router state and use the handoff artifacts for future
   maintenance. The CLI and LuCI transaction paths are verified.

## Decisions and constraints

- Keep POSIX shell and existing router dependencies; do not require Python on
  the router.
- Never expose or commit UUID, Reality keys, short IDs, or other credentials.
- Preserve the verified gVisor TUN, routes, firewall, cache, and service setup.
- Do not reintroduce Podkop.
- `active-profile` changes only after all switch checks succeed.
- Every post-install switch failure must restore and verify the prior state.
- Do not run production-changing commands during local development.
- Do not guess router commands or connectivity/exit-IP semantics.

## Continuation instructions

Read `AGENTS.md`, `ARCHITECTURE.md`, and this file before changing code.
Inspect `git status` and preserve uncommitted user changes. Continue with the
first unchecked item in “Remaining work”, updating this file and
`DEVELOPMENT_PLAN.md` after each completed logical task. Do not request real
provider secrets.

## Latest router verification

The user verified the complete LuCI flow: profile list, profile test, switch
to `Germaniya_2`, Doctor/runtime checks, rollback, and restoration of
`Estoniya_1`. Results matched the expected outputs exactly. The latest
read-only check reports active profile `Estoniya_1` and
`active_config_match` is `true`.

## Next feature: automatic failover

The agreed design is documented in `ARCHITECTURE.md`. It is not implemented
yet. The planned watchdog will run as an OpenWrt `procd` service, use both
`example.com` and `api.ipify.org` checks, require three consecutive failures,
use explicit profile priority and cooldown, and remain on a recovered working
profile until a manual switch or the next failure. Automatic failback is not
planned.

Automatic switching will use the existing transactional CLI path and a
separate bounded recovery area under `/etc/sing-box/backups/automatic/`.
Successful transitions retain only the single previous known-good automatic
backup; manual and historical backups are not removed.

The first implementation slice is now present: disabled-by-default sample UCI
configuration at `config/overfog-manager`, shared `lib/watchdog.sh` helpers,
and secret-safe `overfogctl watchdog config/state` diagnostics. The local
monitor loop, operation lock, automatic candidate switching, cooldown, bounded
automatic backup pruning, and `procd` service have now been implemented but
are deployed in the disabled state. Router shell syntax and config/state
diagnostics passed; the controlled monitor-once failover path is router-
validated. The watchdog is now enabled through UCI and its `procd` process has
passed two 60-second healthy cycles without switching.

A one-shot watchdog run was validated on the router with temporary state and
the confirmed profile order. It reported `Watchdog healthy: Germaniya_2` and
wrote zero consecutive failures with an empty cooldown map. No switch or
restart occurred.

A controlled failover test was completed on 2026-09-23. A temporary curl
simulator caused three consecutive failed health cycles. The watchdog switched
from the actual starting profile `Estoniya_1` to `Germaniya_2`; rollback then
restored `Estoniya_1`. Both states passed Doctor, including
`active_config_match: true`, and the temporary simulator/state/backup files
were removed. The watchdog service remains disabled.

The subsequent long-running test enabled the watchdog and its service
autostart. Two 60-second cycles completed with `Estoniya_1` active, zero
consecutive failures, empty cooldown, and healthy Doctor output. The deployment
script now preserves an existing `/etc/config/overfog-manager` instead of
overwriting runtime watchdog settings.

For every significant design, implementation, deployment, or verification
change, update the architecture, development-plan, project-state, and—when
applicable—deployment-log artifacts in the same change.

## Installer direction

The agreed installer UX uses one self-extracting `overfog-manager-installer.run`
bundle. It can be downloaded from GitHub or copied to the router and run
offline. Before writing, it inventories the router and offers grouped choices:
`CLI`, `LuCI`, `watchdog`, and `configuration`; each group supports keep,
backup-and-update, skip, or abort. Existing sing-box configuration, profiles,
and active-profile are never overwritten by manager installation. Installer
implementation is the next development task.

The first installer implementation slice now exists locally: grouped
interactive installation for CLI, LuCI, watchdog, and configuration; a
self-extracting launcher; and `scripts/build-installer.sh` for producing the
online/offline `.run` bundle. A real bundle was built on the router and passed
`--check`, detecting the current CLI, LuCI, watchdog, configuration, sing-box
config, and active profile without writing files. The installer never includes
or replaces `/etc/sing-box/config.json`.

The user also ran the interactive installer and selected `keep` for all four
groups (`CLI`, `LuCI`, `watchdog`, `configuration`). It completed successfully
without updating files or changing sing-box. The non-destructive repeat-run
path is verified.

The user then selected `update` for the `CLI` group and `keep` for the other
groups. The installer created deployment backup
`20260923-022809-installer-25775`, normalized shell line endings, and updated
the CLI successfully. Post-update Doctor remained fully healthy with
`Estoniya_1` active and `active_config_match: true`.

The bundle now contains `manifest.json` and `checksums.sha256`; the installer
verifies all payload files before inventory or writes. The updated bundle passed
checksum validation and `--check` on the router. Deployment backup retention is
now implemented as an explicit `--prune-backups` option. It keeps the newest
three `*-installer-*` directories only; ordinary installer runs never delete
backups, and sing-box/profile backups are outside its cleanup scope. GitHub
Release automation is now present in `.github/workflows/release.yml`, with
online/offline instructions in `RELEASE.md`. Release `v0.1.2` is published and
verified on GitHub with the installer and its SHA-256 checksum attached.
