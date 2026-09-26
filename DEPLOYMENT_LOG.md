# Deployment Log

## 2026-09-21 — read-only CLI and LuCI deployment

Target: GL-MT3000 router (address intentionally omitted).

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
address (value intentionally omitted). The final `doctor --json` reported valid config,
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
`tun0`, connectivity, firewall checks, and a valid exit IP (value omitted).
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
exit IP was valid; its value is intentionally omitted.

The CLI transaction path is now verified end-to-end.

## 2026-09-22 — LuCI switch and rollback verification

The user completed the LuCI verification flow successfully: profile list,
profile test, switch to `Germaniya_2`, Doctor/runtime checks, rollback, and
restoration of `Estoniya_1`. The displayed results matched the expected
outputs, including `active_config_match: true`, process/tun0, connectivity,
and firewall checks. The LuCI and CLI transaction paths are now both verified.

## 2026-09-22 — watchdog disabled deployment

The watchdog implementation was deployed with previous files saved under:

```text
/etc/sing-box/backups/overfog-manager-deploy/
```

Installed components:

```text
/usr/bin/overfogctl
/usr/bin/overfog-manager-lib/watchdog.sh
/usr/bin/overfog-manager-lib/lock.sh
/etc/config/overfog-manager
/etc/init.d/overfog-manager-watchdog
```

The UCI configuration is disabled by default (`enabled=0`, interval `60`,
failure threshold `3`, cooldown `600`, empty profile order). Router `sh -n`
checks and secret-safe `watchdog config/state` diagnostics passed. The
watchdog service was not started or enabled, and no profile switch, sing-box
restart, or monitor cycle was executed by this deployment. Final
`doctor --json` remained healthy with active profile `Germaniya_2`, matching
config, running sing-box, `tun0`, connectivity, and firewall checks.

The confirmed watchdog profile order was then written to UCI and committed:

```text
Germaniya_2 Estoniya_1 finland
```

The watchdog remains disabled and no service restart, profile switch, or
monitor cycle was performed. `watchdog config` reported the three profiles in
the confirmed order, and the final Doctor check remained healthy with
`Germaniya_2` active and matching the config.

A one-shot watchdog health check was then run with temporary state and the
confirmed order. It reported `Watchdog healthy: Germaniya_2`, zero consecutive
failures, and an empty cooldown map. The temporary state was removed; no
switch, restart, or persistent watchdog state change occurred.

## 2026-09-23 — controlled automatic failover test

A temporary curl simulator was used only in `/tmp`: the first six curl calls
failed, representing three watchdog health cycles, and later calls returned a
syntactically valid test IPv4. The watchdog automatically switched from the
actual starting profile `Estoniya_1` to `Germaniya_2` after the third failed
cycle. The temporary automatic backup was used by rollback, which restored
`Estoniya_1`; both post-switch and post-rollback Doctor checks reported
`active_config_match: true`.

After cleanup, a real curl/Doctor check succeeded with HTTP 200 and exit IP
valid IPv4. The watchdog service remains disabled and no persistent
watchdog state or temporary simulator files remain.

## 2026-09-23 — watchdog long-running healthy test

The watchdog was enabled in UCI and started through `procd`. The service is
enabled in `/etc/rc.d/` and the monitor process remained running across two
60-second cycles. State stayed at:

```json
{
  "active_profile": "Estoniya_1",
  "consecutive_failures": 0,
  "cooldown": {}
}
```

Doctor remained healthy with valid config, process, `tun0`, connectivity,
firewall checks, and `active_config_match: true`. The deployment script was
changed to preserve an existing UCI watchdog configuration on later deploys,
so a code update cannot silently disable or reorder the live watchdog.

## 2026-09-23 — installer bundle check

The self-extracting installer was assembled in a temporary router directory
and executed with `--check`. It correctly detected the GL-MT3000/OpenWrt
25.12.5, installed CLI/LuCI/watchdog/configuration groups, existing sing-box
config, and active profile `Estoniya_1`. It exited in check-only mode without
writing production files. The installer was adjusted to use `cp -p` and
`chmod` because this OpenWrt image does not provide a standalone `install`
command.

The installer bundle was then extended with `manifest.json` and
`checksums.sha256`. A rebuilt bundle passed checksum verification and
`--check` on the router, again without changing production files.

The installer now supports explicit `--prune-backups`; it removes only the
oldest `*-installer-*` deployment directories after retaining the newest three.
The updated bundle was rebuilt and passed checksum verification and `--check`
on the router. No production files were changed by this check.

The user then ran the bundle in interactive mode and selected `keep` for all
four existing groups. The installer completed successfully, created no update
backup because no group was changed, and reported that sing-box configuration
was not changed.

The next run selected `update` for `CLI` and `keep` for LuCI, watchdog, and
configuration. It created:

```text
/etc/sing-box/backups/overfog-manager-deploy/20260923-022809-installer-25775
```

The CLI update completed successfully after the installer normalized CRLF shell
files. `doctor --json` remained healthy: config valid, process/tun0/connectivity
and firewall checks successful, `Estoniya_1` active, and
`active_config_match: true`. Sing-box configuration was not changed.

## 2026-09-24 — first GitHub release

Release `v0.1.2` was published from the sanitized source tree. GitHub Actions
successfully attached `overfog-manager-installer.run` and its `.sha256` file.

## 2026-09-26 — provider-neutral watchdog order validation

The updated CLI libraries, watchdog init script, and LuCI controller/view were
syntax-checked in a temporary router directory, then deployed with a separate
backup under `overfog-manager-deploy/20260926-watchdog-order`. The deploy did
not modify sing-box configuration, profiles, or the active profile. uhttpd was
reloaded and the enabled watchdog was restarted.

The existing order was migrated from its legacy single UCI option to a UCI list.
Moving `finland` up/down, removing and re-adding it, and a healthy one-shot
watchdog check all succeeded. A temporary newly created profile was appended
automatically, then removed along with its order entry. Final order and active
profile remained unchanged; Doctor confirmed config, process, tun0,
connectivity, firewall, and active-config matching were healthy.

## 2026-09-27 — protected profile deletion deployment

The updated CLI entry point, profile helper, and LuCI controller/view were
syntax-checked on the router, deployed atomically, and the previous files were
saved under `overfog-manager-deploy/20260927-profile-delete`. Only `uhttpd` was
reloaded; sing-box, profiles, and the active configuration were not modified.
The new `profile-delete` command and LuCI template entry are present. A final
Doctor check remained healthy with `Singapur` active and
`active_config_match: true`. Functional deletion of a non-active profile is
still intentionally left for browser confirmation.

## 2026-09-27 — LuCI POST/redirect/GET update

The LuCI controller was updated to redirect every POST request to the overview
GET URL after completion. This prevents a browser refresh from resubmitting an
operation. The previous controller is retained under
`overfog-manager-deploy/20260927-prg`. The deployed controller passed Lua
syntax validation, uhttpd was reloaded, and Doctor remained healthy with
`Singapur` active and `active_config_match: true`.

## 2026-09-27 — operation-lock and LuCI progress overlay

The CLI and LuCI view were updated with a shared mutation lock and a full-page
progress overlay for every LuCI POST. The previous files are retained under
`overfog-manager-deploy/20260927-operation-lock`. The new shell entry point
passed `sh -n`; uhttpd was reloaded without restarting sing-box. The overlay
was confirmed present in the deployed view, no stale operation lock remained,
and Doctor remained fully healthy with `Singapur` active and
`active_config_match: true`.

## 2026-09-27 — LuCI operation-result correction

The redirect controller originally reported every POST as completed even when
the invoked CLI command returned a failure code. It now uses `luci.sys.call`
and redirects with a safe success/failure result only; the overview reports a
failure explicitly and continues to display the actual active profile. The
controller was syntax-checked and deployed with its prior version saved under
`overfog-manager-deploy/20260927-operation-result`. uhttpd was reloaded only;
Doctor remained healthy with `Singapur` active and `active_config_match: true`.
`overfogctl test Germaniya_2` succeeded without changing the active VPN.

## 2026-09-27 — LuCI overlay form-submission correction

The first overlay implementation disabled form inputs during the submit event,
which caused the browser to omit hidden token/action/profile fields from the
POST. Consequently, LuCI rejected the request before invoking the CLI. The
overlay now blocks interaction visually and through its one-submit guard while
leaving submitted fields enabled. The corrected view was deployed with the
prior version saved under `overfog-manager-deploy/20260927-overlay-submit`;
uhttpd was reloaded only. Doctor remained healthy with `Singapur` active and
`active_config_match: true`.
