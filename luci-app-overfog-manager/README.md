# luci-app-overfog-manager

LuCI integration for `overfog-manager`.

The page executes the shared `overfogctl` commands. It provides a compact
status summary, profile table with per-profile test/switch actions, HAPP/Xray
file or paste import, failover-order management, diagnostics, and rollback.
It contains no independent profile or transaction logic.

The package expects the CLI and its shared libraries to be installed at:

- `/usr/bin/overfogctl`
- `/usr/bin/overfog-manager-lib/`

The LuCI controller is legacy-Lua compatible with the installed
`luci-compat`; the backend command remains the shared shell CLI.

## Router installation layout

Copy these files to the matching paths, then reload LuCI/rpcd as appropriate:

The repository helper is `scripts/install-luci.sh`; it only installs the
controller and template and does not restart services.

```text
luasrc/controller/overfog-manager.lua
    -> /usr/lib/lua/luci/controller/overfog-manager.lua
luasrc/view/overfog-manager/overview.htm
    -> /usr/lib/lua/luci/view/overfog-manager/overview.htm
```

The page is protected by the existing authenticated LuCI admin controller path.
It is not exposed as a separate unauthenticated rpcd object. Action behavior
must be tested on the router before broader ACL changes are considered.
