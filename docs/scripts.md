# Scripts

`scripts/` contains installer, config, ops, system, desktop, and maintenance helpers.

## Naming

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

`inst-*.sh` scripts are sourced by `init.sh` after `globals.sh` loads.

- Check the binary or version before downloading.
- Reinstall only when `FORCE=true`.
- Use `cmd_exist`, `pkg_install`, `installPackages`, and `gh_latest_release` when possible.
- Support `ubuntu`, `debian`, `linuxmint`, `arch`, `centos`, and macOS for developer tools when practical.
- Do not assume interactive-shell PATH setup; source needed `env/*.sh` files.

## Validation

| Change | Check |
|---|---|
| Any shell script | Pre-commit, or `make test` when not committing |
| Installer/bootstrap behavior | Above plus `make test-init` |
| `inst-opencode.sh` | `make test-inst-opencode` |
| `inst-picom.sh` | `make test-inst-picom` |
| Shell lint/formatting | `make lint` or `make test-lint` |

Docker and UI tests can mutate state or take focus; announce them before running.
