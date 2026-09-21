# overfog-manager

CLI manager for the verified sing-box VLESS+REALITY setup on the GL-MT3000.

The current repository milestone preserves the existing non-destructive shell
prototype in [`overfogctl`](overfogctl). It supports:

- `status`
- `list`
- `profile-create NAME [COUNTRY]`
- `test PROFILE`
- `switch PROFILE` (router only)
- `rollback` (router only)
- `doctor [--json]` (read-only)
- `import FILE [--country COUNTRY]` (does not activate the profile)

The commands use the production paths by default. For local tests and dry-run
work, override them with `OVERFOG_CONFIG`, `OVERFOG_PROFILE_DIR`,
`OVERFOG_BACKUP_DIR`, and `OVERFOG_ACTIVE_FILE`. Optional direct-route probes
use `OVERFOG_DIRECT_PROBE_RU` and `OVERFOG_DIRECT_PROBE_BY`.
No provider credentials belong in this repository.

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
