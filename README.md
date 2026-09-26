# overfog-manager

CLI manager for the verified sing-box VLESS+REALITY setup on the GL-MT3000.

The current repository milestone preserves the existing non-destructive shell
prototype in [`overfogctl`](overfogctl). It supports:

- `status`
- `list`
- `profile-create NAME [COUNTRY]`
- `profile-delete PROFILE [--purge-backups]` (never deletes the active profile)
- `test PROFILE`
- `switch PROFILE` (router only)
- `rollback` (router only)
- `doctor [--json]` (read-only)
- `import FILE [--country COUNTRY]` (does not activate the profile)
- `watchdog config`, `watchdog configure`, `watchdog state`, `watchdog profiles`,
  `watchdog profile-add`, `watchdog profile-remove`, `watchdog profile-move`,
  `watchdog once`, and `watchdog monitor`
  (the monitor is disabled by default)

The commands use the production paths by default. For local tests and dry-run
work, override them with `OVERFOG_CONFIG`, `OVERFOG_PROFILE_DIR`,
`OVERFOG_BACKUP_DIR`, and `OVERFOG_ACTIVE_FILE`. Optional direct-route probes
use `OVERFOG_DIRECT_PROBE_RU` and `OVERFOG_DIRECT_PROBE_BY`.
No provider credentials belong in this repository.

The release installer is the canonical deployment path because it inventories
existing files, asks per-group before updating, and creates recoverable
deployment backups. The older `scripts/install.sh`, `scripts/deploy.sh`, and
`scripts/install-luci.sh` helpers remain for development use. The install
helpers preserve existing files by default and require
`OVERFOG_ALLOW_OVERWRITE=1` for an explicit replacement; `deploy.sh` creates a
remote backup before its deliberate replacement.

## Local checks

```text
python -m unittest discover -s tests -v
```

The shell CLI itself requires the router's existing `jq`, `sing-box`, `pgrep`,
and `ip` dependencies when run against the router.

## Planned work

Rollback is available as a separate command and is also used automatically by
`switch`. HAPP/Xray import derives a safe profile name from `remarks` and does
not activate the imported profile.

Automatic failover is implemented as a disabled-by-default watchdog. The
distributed fallback list is empty and contains no provider-specific names.
Newly created or imported profiles are appended automatically. With one
profile, the watchdog still checks health but cannot switch; with an empty
fallback list it reports that no candidates are configured. The order is
managed explicitly from LuCI and is preserved during manager updates.
