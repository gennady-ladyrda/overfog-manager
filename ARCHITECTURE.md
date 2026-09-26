# Overfog Manager — Architecture and Constraints

## Purpose

`overfog-manager` manages VLESS+REALITY Overfog profiles for the verified
sing-box TUN setup on the GL-MT3000. The manager must preserve the working
router configuration and must never activate an unvalidated profile.

## Runtime architecture

The runtime is POSIX shell with the dependencies already present on the
router: `sh`, `jq`, `sing-box`, `pgrep`, `ip`, and the OpenWrt service tools.
Python is not a router dependency.

```text
overfogctl                  CLI entry point and command dispatch
└── lib/
    ├── paths.sh             production paths and test overrides
    ├── profiles.sh          profile discovery and validation
    ├── config.sh            candidate configuration generation
    ├── checks.sh            syntax and runtime checks
    ├── service.sh            restart and basic runtime wait
    ├── import.sh             HAPP/Xray to normalized profile conversion
    └── transaction.sh       backup, atomic install, restore
```

The service restart operation is centralized in `lib/service.sh`. The
confirmed router command is `/etc/init.d/sing-box restart`.

`overfogctl` and a future LuCI wrapper must call the same functions from
`lib/`. LuCI must not contain an independent switching implementation.

## State and files

Production defaults remain:

- `/etc/sing-box/config.json` — active sing-box configuration;
- `/etc/sing-box/profiles/` — profile files, directory mode `700`;
- `/etc/sing-box/backups/` — known-good backups, directory mode `700`;
- `/etc/sing-box/active-profile` — active profile name.

Automatic failover state and retention metadata will be kept separately from
manual and historical transaction backups. The planned automatic recovery area
is `/etc/sing-box/backups/automatic/`; it may contain only the single previous
known-good state, its active-profile file, and secret-free metadata. Automatic
cleanup must not remove existing manual or historical backups.

For local tests only, `OVERFOG_CONFIG`, `OVERFOG_PROFILE_DIR`,
`OVERFOG_BACKUP_DIR`, and `OVERFOG_ACTIVE_FILE` may override these paths.

Profiles contain a name, country, and complete normalized `overfog` outbound.
They are not printed in full and are stored with mode `600` on the router.
An inactive profile can be deleted through `profile-delete`. If a rollback
snapshot records that profile as active, deletion requires the explicit
`--purge-backups` option so rollback is never silently degraded. LuCI's Delete
action requires browser confirmation and uses that explicit option.

`import FILE [--country COUNTRY]` derives the profile name from the source
HAPP/Xray `remarks` field. Leading/trailing whitespace is removed, whitespace
becomes `_`, Cyrillic letters are transliterated to Latin, and decorative
characters are removed. Import is non-activating and refuses to overwrite an
existing profile. For example, `Германия №2` becomes `Germaniya_2`.

`doctor --json` exposes the same read-only checks without secrets, allowing a
future LuCI wrapper to consume the result without duplicating diagnostic logic.

The LuCI slice renders a compact status summary and profile table from
`doctor --json` and `list --json`. Test, import, switch, rollback, and watchdog
order actions are delegated to the shared CLI through the authenticated
controller path. Destructive actions use explicit confirmation dialogs and
POST forms carry the LuCI session token. Raw diagnostics remain available only
inside an expandable details section.
Every state-changing LuCI form uses a POST/redirect/GET response flow, so a
browser refresh cannot repeat a switch, import, delete, rollback, or watchdog
configuration request.
While a LuCI POST is in flight, a full-page progress overlay prevents any
interaction without disabling submitted form fields before the browser sends
them. The same shared server-side operation lock serializes all profile,
switch, rollback, and watchdog mutations across browser tabs and CLI calls.

## Transaction rules

`switch` must follow this order:

1. validate the profile and candidate structure;
2. generate a temporary full configuration by replacing only `overfog`;
3. run `sing-box check` against the temporary configuration;
4. create an explicit backup of the current known-good state;
5. atomically install the candidate;
6. restart sing-box and run process, interface, and connectivity checks;
7. update `active-profile` only after all checks succeed;
8. on any post-install failure, restore the backup, restart, and verify recovery.

`test` is non-destructive and must never restart sing-box or update active
state.

Historical `fatal/error` matches from `logread` are reported by `doctor` as a
warning but do not block runtime validation. Process, `tun0`, config, and
connectivity checks remain enforced for switching.

## Automatic failover watchdog

The watchdog will run as a separate OpenWrt `procd` service and will invoke the
shared `overfogctl` transaction logic. It must not implement an independent
switching path. Its responsibilities are limited to health observation,
candidate selection, cooldown state, and serialized invocation of the CLI.

The health check requires both of the following to succeed:

- `curl -4 --http1.1 -k --connect-timeout 10 https://example.com/ -o /dev/null`;
- `curl -4 -s https://api.ipify.org`, with a valid IPv4 result.

The IP address is observed and validated, never compared to a fixed expected
address. A single failed probe does not trigger switching. The watchdog uses
three consecutive failed checks to mark the active profile failed. A candidate
must pass the complete post-switch checks before becoming active. Failed
candidates enter a cooldown and must not be retried continuously.

The watchdog remains on the current working profile until a failure or manual
switch. It does not automatically fail back to a higher-priority profile after
that profile recovers. The distributed configuration contains an empty
fallback list and no provider-specific profile names. A newly created or
imported profile is appended automatically to the end of the user's list.
The order can be changed explicitly from LuCI. With one profile, health checks
continue to run, but there is no fallback candidate and no switch is attempted.
An empty list is valid and means that automatic failover has no candidates.
Watchdog enablement, interval, failure threshold, and cooldown are also
editable from the LuCI failover section and are persisted through `overfogctl`.

The current order is user state, not application defaults. Existing order is
preserved during manager updates unless the user explicitly changes it.

The order-management implementation was router-validated on 2026-09-26. It
migrates an existing single UCI option to a UCI list on the first order update,
supports move/remove/re-add operations, and appends a newly created profile.
These operations do not modify sing-box configuration or activate profiles.

Only one monitor, switch, or rollback operation may run at a time. A lock is
required. A failover attempt must use the same backup, atomic replacement,
restart, runtime verification, and automatic restore rules as manual `switch`.

### Automatic backup retention

Before a candidate switch, the current known-good state is saved as a
temporary automatic recovery backup. It is retained while the candidate is
being validated. After a successful switch, it becomes the single automatic
recovery backup and replaces the previous automatic backup. On failure, it is
used to restore the previous profile. This prevents unbounded growth while
preserving recovery during a transaction. Manual and historical backups remain
untouched.

## Documentation maintenance rule

Every significant implementation, deployment, router verification, or design
decision must update the relevant architecture and handoff artifacts in the
same change. At minimum, update `ARCHITECTURE.md` for design or constraint
changes, `DEVELOPMENT_PLAN.md` for task status, and `PROJECT_STATE.md` for
current behavior, verification, and continuation instructions. Deployment or
router changes also update `DEPLOYMENT_LOG.md`. These files are part of the
handoff contract for future sessions and must remain current.

## Router-side installer

Deployment is performed on the router itself. The primary distribution artifact
is a self-extracting `overfog-manager-installer.run` bundle downloaded from a
GitHub Release. The same file can be copied to the router and executed without
network access when GitHub is unavailable. Online and offline installation use
the same installer code and payload.

The installer must perform inventory and display a change plan before any
write. It must never silently overwrite an existing file or sing-box
configuration. Existing manager files are handled in four independent groups:

1. `CLI` — `/usr/bin/overfogctl` and shared manager libraries;
2. `LuCI` — controller and view files;
3. `watchdog` — watchdog init script and watchdog library/config integration;
4. `configuration` — manager UCI configuration and related manager state.

For each group the user chooses `keep`, `backup-and-update`, `skip`, or
`abort`. A replacement creates a deployment backup first. The installer never
replaces `/etc/sing-box/config.json`, profile files, or `active-profile` as a
side effect of installing the manager. Sing-box setup is a separate explicit
operation.

Deployment backups are separate from sing-box recovery backups. The installer
retains the latest three deployment backups and must not delete user profile or
sing-box backups without a separate explicit cleanup choice.

Release distribution uses GitHub Actions. A version tag (`v*`) triggers tests,
POSIX shell syntax checks, self-extracting bundle creation, SHA-256 generation,
and publication of the `.run` installer plus its checksum file. The release
bundle is self-contained so offline installation uses exactly the same payload
and installer code as online installation.

## Security and safety constraints

- Never print or commit UUIDs, Reality public/private-related credentials,
  short IDs, or other provider secrets.
- Use sanitized fixtures only; real provider data stays on the router.
- Do not redesign the verified TUN, routing, firewall, or rule-set cache.
- Do not reintroduce Podkop.
- Prefer atomic replacement and explicit, recoverable backups.
- Do not change `active-profile` before a successful switch.
- Do not execute router-changing operations during local development unless
  explicitly requested.
- Any destructive or irreversible operation requires a known rollback path.

## Development sequence

1. Stabilize and test the existing read-only CLI.
2. Centralize profile validation and candidate generation.
3. Implement and test transactional switching and automatic recovery.
4. Add explicit rollback.
5. Add sanitized HAPP/Xray import.
6. Add read-only diagnostics (`doctor`).
7. Add a thin LuCI interface over the shared core.

The connectivity probes are intentionally left as runtime configuration until
their exact router commands are confirmed. The default external connectivity
probe is the confirmed command using `curl` against `https://example.com/`.
Optional direct-route probes can be supplied through
`OVERFOG_DIRECT_PROBE_RU` and `OVERFOG_DIRECT_PROBE_BY`; unset probes are not
invented or executed.

The transaction helpers are file operations only. They do not restart sing-box
and are not allowed to update active state until the caller has completed all
post-restart checks.
