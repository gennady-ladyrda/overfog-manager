# Deployment Log

## 2026-09-21 — read-only CLI and LuCI deployment

Target: `root@192.168.9.1` (GL-MT3000).

The deployment used legacy SCP protocol because the router does not provide
`/usr/libexec/sftp-server`.

Before replacing files, the existing CLI was backed up to:

```text
/etc/sing-box/backups/overfog-manager-deploy/overfogctl.previous
```

The deployed CLI and libraries are:

```text
/usr/bin/overfogctl
/usr/bin/overfog-manager-lib/*.sh
```

The existing LuCI files, if present, were backed up under:

```text
/etc/sing-box/backups/overfog-manager-deploy/luci-controller/
/etc/sing-box/backups/overfog-manager-deploy/luci-view/
```

The read-only LuCI files are:

```text
/usr/lib/lua/luci/controller/overfog-manager.lua
/usr/lib/lua/luci/view/overfog-manager/overview.htm
```

No sing-box restart, profile switch, rollback, or active-profile update was
performed during deployment.

## Read-only verification

`overfogctl doctor --json` on the router reported:

- configuration valid;
- process running;
- `tun0` present;
- cache present;
- active profile exists and matches current config;
- external connectivity working;
- exit IP returned and valid IPv4;
- `singbox` zone on `tun0` valid;
- `lan -> singbox` forwarding valid;
- log cleanliness failed because matching historical `fatal/error` entries
  exist and their raw contents were intentionally not copied into the repo.

`status`, `list`, and `test finland` completed successfully.

## Follow-up — historical log handling

The router confirmed that matching `fatal/error` entries are historical. The
runtime check was changed so process, `tun0`, config, connectivity, and exit
IP remain enforced, while historical log matches are reported as an
informational warning and do not block `switch`. The router was updated with
the revised CLI/libraries and `doctor --json` was re-run successfully.

## Follow-up — LuCI action forms

The LuCI controller and template were updated and deployed after preserving
the previous read-only files under:

```text
/etc/sing-box/backups/overfog-manager-deploy/luci-actions-previous/
```

The page now provides forms for `test`, HAPP/Xray `import`, `switch`, and
`rollback`. All forms invoke `/usr/bin/overfogctl`; no switching or rollback
was executed during this deployment. The Lua controller passed a remote
`loadfile()` syntax check, and `luci.util.shellquote` is available.

The user verified that the LuCI `test` action works successfully. No profile
activation or service restart was performed by that verification.

The first LuCI import exposed a naming issue: `remarks` produced
`_Германия_№2`. Leading Unicode whitespace and decorative punctuation need a
dedicated normalization rule before imported profiles are considered polished.

The local importer now transliterates Cyrillic and strips emoji/decorative
punctuation. The same remarks should produce `Germaniya_2`; the router needs a
new CLI deployment and re-import to validate this behavior. The normalization
core was checked on the sanitized fixture directly on the router and produced
`Germaniya_Premium`.

The user re-imported the provider profile after the naming fix. It created
`Germaniya_2`, and `test` completed successfully with `sing-box check`.

The LuCI import form now accepts either a file upload or pasted HAPP/Xray JSON
from the clipboard. The file-upload option remains available.

An empty multipart file field was found to shadow pasted JSON; the controller
now ignores empty file metadata and correctly falls back to the textarea.

The paste path was verified in LuCI: the result reported `Source: paste` and
then safely rejected the duplicate `Germaniya_2` profile. This confirms that
the pasted JSON reaches the shared importer and duplicate protection works.

## Follow-up — profile list in LuCI

The CLI now supports secret-safe `overfogctl list --json`, returning only
profile name, country, server, port, and active state. The LuCI overview renders
this output in a separate profile list and continues to delegate all operations
to the shared CLI. The router-side command was checked read-only; it showed the
active `finland` profile and the existing imported profiles. No restart,
switch, rollback, or profile deletion was performed.

## 2026-09-22 — confirmed CLI switch

With explicit user confirmation, the router executed:

```text
/usr/bin/overfogctl switch Germaniya_2
```

The transaction succeeded and created the backup:

```text
/etc/sing-box/backups/20260922-210641-19955.config.json
```

Post-switch checks succeeded: sing-box process running, `tun0` present,
`example.com` returned HTTP 200, and `api.ipify.org` returned a valid IPv4
address (`2.27.4.95`). The final `doctor --json` reported valid config,
active profile `Germaniya_2`, active/config match, connectivity, cache, and
firewall checks all successful. `log_clean` remains false because the log
contains historical/reconnect `ERROR` entries; this field is informational and
does not block a successful transaction.

Rollback was not executed yet.

## 2026-09-22 — clean switch test with Estoniya_1

The manually added `Estoniya_1` profile was tested and switched successfully:

```text
/usr/bin/overfogctl test Estoniya_1
/usr/bin/overfogctl switch Estoniya_1
```

The profile passed `sing-box check`. The resulting `doctor --json` reported
`active_profile: Estoniya_1`, `active_config_match: true`, running sing-box,
`tun0`, connectivity, firewall checks, and valid exit IP `217.60.100.107`.
The connectivity probe returned HTTP 200. The switch backup was
`20260922-211508-24715.config.json`.

For a clean rollback test, the next switch should be from this consistent
`Estoniya_1` state to another profile, followed by rollback. This avoids using
the older `finland` state whose profile file was manually changed.

## 2026-09-22 — clean switch and rollback verification

With explicit confirmation, the following sequence was executed:

```text
switch Germaniya_2
rollback
```

The switch created backup `20260922-211646-25771.config.json` and completed
successfully. Rollback restored that consistent pre-switch state. Final
diagnostics reported `active_profile: Estoniya_1`,
`active_config_match: true`, valid config, running sing-box, `tun0`, cache,
connectivity, and firewall checks. The HTTP probe returned 200 and the final
exit IP was `217.60.100.107`.

The CLI transaction path is now verified end-to-end.

## 2026-09-22 — LuCI switch and rollback verification

The user completed the LuCI verification flow successfully: profile list,
profile test, switch to `Germaniya_2`, Doctor/runtime checks, rollback, and
restoration of `Estoniya_1`. The displayed results matched the expected
outputs, including `active_config_match: true`, process/tun0, connectivity,
and firewall checks. The LuCI and CLI transaction paths are now both verified.
