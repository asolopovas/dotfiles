# Scripts

`scripts/` holds installer, config, ops, system, desktop, WSL, and maintenance helpers.

## Names

Use `{prefix}-{name}.sh` in the matching category directory.

| Prefix | Use |
|---|---|
| `inst-` | Install one tool, runtime, package group, or service |
| `cfg-` | Configure local/system settings |
| `ops-` | Operate or maintain services/data |
| `sec-` | Security, certs, permissions, keyrings |
| `sys-` | System fixes, kernel, drivers, limits |
| `ui-` | Desktop, window manager, displays, panels |
| `wsl-` | WSL and Windows interop |

Commands installed into `~/.local/bin` may omit `.sh` when the filename is the user interface.

## Installer contract

`inst-*.sh` scripts are sourced by `init.sh` after `globals.sh` loads. They must check binary/version before downloads, reinstall only with `FORCE=true`, use `installPackages`/`pkg_install` and prefer `gh_latest_release`, support the repo OS matrix, and source needed `env/*.sh` instead of assuming interactive PATH.

Validation routing: [testing.md](testing.md).
