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
