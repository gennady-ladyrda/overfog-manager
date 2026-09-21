# Prompt for the PyCharm CLI agent

We are continuing development of `overfog-manager`. Read `AGENTS.md` and `PROJECT_STATE.md` completely before changing anything.

The production GL-MT3000 router already has a working, reboot-tested sing-box VLESS+REALITY TUN setup and a prototype `/usr/bin/overfogctl`. Do not redesign or replace the working VPN configuration. Our goal now is to turn the verified prototype into a local Git project with tests, then implement safe transactional profile switching, rollback, HAPP/Xray import, diagnostics, and later a LuCI UI.

Start with the immediate milestone in `PROJECT_STATE.md`: bootstrap the repository and reproduce the existing non-destructive CLI functionality locally. Preserve all safety constraints from `AGENTS.md`. Do not use or request real provider secrets; use sanitized fixtures.

Before making changes, inspect the repository/worktree and report your proposed file changes. Then proceed incrementally and show diffs/tests after each logical step.
