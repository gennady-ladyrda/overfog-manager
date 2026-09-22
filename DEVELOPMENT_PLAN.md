# Development Plan

Status markers: `[x]` implemented in the repository, `[~]` partially
implemented or awaiting external confirmation, `[ ]` not implemented.

- [x] Preserve the router-derived read-only CLI.
- [x] Sanitize fixtures and add repository tests.
- [x] Centralize paths, profile validation, candidate generation, checks,
  service restart, and transaction file operations.
- [x] Implement transactional `switch` with automatic restore.
- [x] Validate `switch` on the router with `Germaniya_2` and `Estoniya_1`;
  backup creation, restart, process/tun0/connectivity/exit-IP checks, and
  active-profile updates all succeeded.
- [x] Add explicit `rollback` command and managed backup selection; clean
  router test restored `Estoniya_1` with `active_config_match: true`.
- [x] Add read-only `doctor` with secret-safe structured output (human and
  JSON), including the confirmed firewall zone/forwarding checks and IP
  format observation.
- [x] Add HAPP/Xray conversion core and CLI import from `remarks`.
- [x] Add connectivity and exit-IP format checks using the confirmed curl
  commands; the returned IP is observed, not compared with the server address.
- [x] Add POSIX shell integration test harness; execution still requires a
  POSIX environment with `sh` and `jq`.
- [x] Add LuCI thin UI over shared operations; test/import, switch, and
  rollback were verified through the router UI using the shared CLI.
- [x] Improve imported profile naming: normalize whitespace, remove emoji and
  decorative punctuation such as `№`, prevent leading separators, and
  transliterate Cyrillic to Latin (`Германия` becomes `Germaniya`).
- [x] Document automatic failover architecture, health criteria, no-failback
  policy, serialized switching, cooldown, and bounded automatic backups.
- [x] Add disabled-by-default UCI watchdog configuration and secret-safe state
  helpers/diagnostics.
- [~] Implement the automatic failover watchdog as an OpenWrt `procd` service;
  monitor loop, lock, cooldown, candidate failover, and bounded automatic
  backup code exist locally but are not yet router-validated.
- [x] Add configurable profile priority, failure threshold, probe interval,
  cooldown, and secret-free watchdog state/diagnostics.
- [x] Configure the confirmed router priority order:
  `Germaniya_2 Estoniya_1 finland`.
- [x] Run a one-shot healthy watchdog check on the router using temporary
  state; no switch was triggered.
- [x] Test automatic failover and bounded backup retention on the router with
  a temporary six-failure curl simulator and cleanup after rollback.
- [x] Run two healthy 60-second cycles with watchdog enabled under `procd`.

## Rules for updating this file

Mark an item `[x]` only when code and relevant tests exist. Use `[~]` when
implementation is incomplete or depends on a router-side confirmation. Record
new commands and assumptions in `ARCHITECTURE.md` and `PROJECT_STATE.md`.
