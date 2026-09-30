# Overfog Manager — Current State / Handoff

## Current status

The router VPN configuration is healthy and reboot-tested. The repository now
contains the router-derived POSIX shell CLI and shared shell libraries. The
profiles `Germaniya_2` and `Estoniya_1` were switched successfully on the
router on 2026-09-22. A clean `switch → rollback` test completed successfully.
The latest router read-only check reports `Estoniya_1` active and matching the
active config.

The distributed watchdog configuration is provider-neutral: its fallback list
is empty, and no profile names are imposed on a new installation. New profiles
are appended automatically; LuCI controls explicit reordering. With one
profile, health is monitored but no failover candidate exists. The current
router's existing order is user state and is not changed by this repository
update.

The current CLI commands are:

- `status`
- `list [--json]`
- `profile-create NAME [COUNTRY]`
- `profile-delete PROFILE [--purge-backups]`
- `test PROFILE`
- `switch PROFILE`
- `rollback`
- `doctor`
- `import FILE [--country COUNTRY]`
- `watchdog profiles [--json]`
- `watchdog configure ENABLED INTERVAL FAILURE_THRESHOLD COOLDOWN`
- `watchdog profile-add PROFILE`
- `watchdog profile-remove PROFILE`
- `watchdog profile-move PROFILE {up|down}`

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

Candidate generation is shared by `test` and `switch`, which are also the
operations delegated by LuCI. It now normalizes the static split-routing policy
on every candidate: sniff, TCP/UDP port 53 to `direct`, `.ru`/`.su`/`.by` to
`direct`, Russian geosite and geoip rule sets to `direct`, then existing later
bypass rules and `route.final = overfog`. It removes the obsolete
`protocol: dns` rule, the temporary exact `2ip.ru` diagnostic rule, and any
physical-interface binding on the `direct` outbound. `route.auto_detect_interface`
remains enabled; the TUN configuration is retained unchanged.

`rollback` selects the latest managed switch backup, saves the current state
as a separate pre-rollback backup, restores atomically, restarts, and verifies
runtime. `doctor` is read-only and reports configuration, process, tun0, log,
cache, active-profile drift, external connectivity, exit-IP format, the
singbox zone on tun0, and LAN-to-singbox forwarding. Exit IP is observed via
api.ipify and is not compared with the VLESS server address. Historical
`fatal/error` log matches are informational and do not block switching.

## Verification status

Local Python tests: 14 passed and 1 shell-syntax test was skipped because this
Windows environment has no usable POSIX `sh`. GitHub Actions installs `jq` and
runs the integration test. The updated OpenWrt order-management path was
rechecked on the router on 2026-09-26.

The supplied curl probe verifies external reachability. The api.ipify probe
observes and validates the returned IPv4 format; it does not assert a fixed
value because the exit IP is dynamic.

## Remaining work, in order

1. Run the updated release workflow and POSIX integration test in CI.
2. Visually confirm the refreshed LuCI page's order controls in a browser.
3. Keep the verified router state and use the handoff artifacts for future
   maintenance. Git operations remain the repository owner's responsibility.

The provider-neutral watchdog order update was deployed and router-validated
on 2026-09-26. The controller was syntax-checked and uhttpd reloaded; a visual
LuCI browser confirmation remains a follow-up. Git operations are intentionally
left to the repository owner.

The LuCI page was redesigned locally around a status summary and profile table.
Import, failover order, diagnostics, and recovery are now separate expandable
sections. Profile actions are attached to table rows, confirmation checkboxes
were removed, and state-changing POST forms require the LuCI session token.
The updated page has not yet been deployed to the router.

The local LuCI and CLI changes now also provide deletion of an inactive profile.
Deletion removes it from the watchdog order. If a managed rollback snapshot
would restore that profile, the CLI requires explicit `--purge-backups`; the
LuCI confirmation uses it so rollback cannot silently restore a config whose
profile file no longer exists. The files were deployed and syntax-checked on
the router on 2026-09-27; browser confirmation of an actual non-active-profile
deletion remains outstanding.

All LuCI POST operations now use POST/redirect/GET. This was deployed and
syntax-checked on the router on 2026-09-27, so refreshing the overview after an
operation does not ask the browser to resend form data.

LuCI now displays a full-page progress overlay and disables all controls as
soon as a POST is submitted. The shared CLI operation lock also serializes
profile creation/import/deletion, switch/rollback, and watchdog mutations
across CLI calls and browser tabs. This was deployed and runtime-checked on
the router on 2026-09-27; browser visual confirmation remains outstanding.

The LuCI POST/redirect/GET result handling now reflects the CLI exit code.
It no longer labels a failed switch as successful. The correction was deployed
on 2026-09-27; the active profile remained `Singapur`, and a non-destructive
test of `Germaniya_2` passed.

The first in-flight overlay implementation was corrected after it disabled
hidden submitted fields, causing LuCI to reject operations before CLI execution.
The deployed overlay now blocks interaction without disabling form data. The
active profile remains `Singapur`; a browser retry of switching to `Germaniya_2`
is the required follow-up.

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

## Automatic failover status

The agreed design is documented in `ARCHITECTURE.md`. The watchdog runs as an
OpenWrt `procd` service, uses both `example.com` and `api.ipify.org` checks,
requires three consecutive failures, uses a user-managed fallback order and
cooldown, and remains on a recovered working profile until a manual switch or
the next failure. Automatic failback is not planned.

Automatic switching will use the existing transactional CLI path and a
separate bounded recovery area under `/etc/sing-box/backups/automatic/`.
Successful transitions retain only the single previous known-good automatic
backup; manual and historical backups are not removed.

The implementation includes disabled-by-default UCI configuration at
`config/overfog-manager`, shared `lib/watchdog.sh` helpers, secret-safe
diagnostics, the monitor loop, operation lock, automatic candidate switching,
cooldown, bounded automatic backup pruning, and the `procd` service. The
distributed fallback list is now empty and provider-neutral. Profile creation
and import append new profiles automatically; CLI and LuCI expose explicit
reordering and removal. Router validation of this latest order-management
change remains outstanding.

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
