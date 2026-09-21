# Development Plan

Status markers: `[x]` implemented in the repository, `[~]` partially
implemented or awaiting external confirmation, `[ ]` not implemented.

- [x] Preserve the router-derived read-only CLI.
- [x] Sanitize fixtures and add repository tests.
- [x] Centralize paths, profile validation, candidate generation, checks,
  service restart, and transaction file operations.
- [x] Implement transactional `switch` with automatic restore.
- [~] Validate `switch` on the router; CLI/LuCI read-only deployment is done,
  profile-changing test still requires explicit confirmation.
- [x] Add explicit `rollback` command and managed backup selection.
- [x] Add read-only `doctor` with secret-safe structured output (human and
  JSON), including the confirmed firewall zone/forwarding checks and IP
  format observation.
- [x] Add HAPP/Xray conversion core and CLI import from `remarks`.
- [x] Add connectivity and exit-IP format checks using the confirmed curl
  commands; the returned IP is observed, not compared with the server address.
- [x] Add POSIX shell integration test harness; execution still requires a
  POSIX environment with `sh` and `jq`.
- [~] Add LuCI thin UI over shared operations; `test` is browser-verified,
  while import/switch/rollback still require router validation.

## Rules for updating this file

Mark an item `[x]` only when code and relevant tests exist. Use `[~]` when
implementation is incomplete or depends on a router-side confirmation. Record
new commands and assumptions in `ARCHITECTURE.md` and `PROJECT_STATE.md`.
