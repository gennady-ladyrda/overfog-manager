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

For local tests only, `OVERFOG_CONFIG`, `OVERFOG_PROFILE_DIR`,
`OVERFOG_BACKUP_DIR`, and `OVERFOG_ACTIVE_FILE` may override these paths.

Profiles contain a name, country, and complete normalized `overfog` outbound.
They are not printed in full and are stored with mode `600` on the router.

`import FILE [--country COUNTRY]` derives the profile name from the source
HAPP/Xray `remarks` field. Leading/trailing whitespace is removed, whitespace
becomes `_`, Cyrillic letters are transliterated to Latin, and decorative
characters are removed. Import is non-activating and refuses to overwrite an
existing profile. For example, `Германия №2` becomes `Germaniya_2`.

`doctor --json` exposes the same read-only checks without secrets, allowing a
future LuCI wrapper to consume the result without duplicating diagnostic logic.

The LuCI slice renders `doctor --json` and `list --json` and delegates test,
import, switch, and rollback actions to the shared CLI through the existing
authenticated controller path. Switch and rollback remain confirmation-gated
and require router-side validation before use.

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
