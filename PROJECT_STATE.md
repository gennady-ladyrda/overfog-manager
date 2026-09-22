# Overfog Manager — Current State / Handoff

## Current status

The router VPN configuration is healthy and reboot-tested. The repository now
contains the router-derived POSIX shell CLI and shared shell libraries. The
profiles `Germaniya_2` and `Estoniya_1` were switched successfully on the
router on 2026-09-22. A clean `switch → rollback` test completed successfully;
`Estoniya_1` is currently active and matches the active config.

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
`Estoniya_1`. Results matched the expected outputs exactly. The final active
profile is `Estoniya_1` and `active_config_match` is `true`.
