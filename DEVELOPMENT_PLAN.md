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
- [x] Make the distributed watchdog fallback list empty and provider-neutral;
  append newly created/imported profiles automatically.
- [x] Add explicit watchdog profile-order controls to the CLI and LuCI,
  including one-profile/no-fallback behavior.
- [x] Simplify LuCI into a status summary, profile table, compact import flow,
  expandable failover/diagnostics/recovery sections, and token-protected POST
  actions.
- [~] Add protected inactive-profile deletion to the shared CLI and LuCI;
  local tests pass, but router deployment and browser validation remain.
- [~] Add LuCI in-flight operation overlay and shared mutation locking; code is
  deployed and runtime-checked, but browser visual confirmation remains.
- [x] Run a one-shot healthy watchdog check on the router using temporary
  state; no switch was triggered.
- [x] Test automatic failover and bounded backup retention on the router with
  a temporary six-failure curl simulator and cleanup after rollback.
- [x] Run two healthy 60-second cycles with watchdog enabled under `procd`.
- [x] Decide grouped installer choices: CLI, LuCI, watchdog, configuration.
- [~] Implement router-side inventory and self-extracting online/offline
  installer with grouped non-destructive choices; a real router-built bundle
  passed `--check`, and the interactive all-`keep` path was verified; the
  CLI update path was verified with backup and Doctor; the installer now
  normalizes shell files. Release packaging and updates for the remaining
  groups remain.
- [x] Add deployment manifest/checksum verification.
- [x] Add explicit `--prune-backups` retention for deployment backups, keeping
  the newest three installer backups.
- [x] Add GitHub Actions release automation for `.run` and `.sha256` artifacts.
- [x] Publish and verify GitHub Release `v0.1.2`.
- [x] Router-validate the provider-neutral watchdog order management update;
  verified migration of the existing order, move, remove/re-add, automatic
  append on profile creation, and no-change healthy one-shot monitoring.
- [x] Normalize the shared candidate route policy: TCP/UDP port 53 uses
  `direct` immediately after sniffing; obsolete DNS-protocol and temporary
  `2ip.ru` rules are removed; direct is not pinned to a physical uplink.

## Rules for updating this file

Mark an item `[x]` only when code and relevant tests exist. Use `[~]` when
implementation is incomplete or depends on a router-side confirmation. Record
new commands and assumptions in `ARCHITECTURE.md` and `PROJECT_STATE.md`.
