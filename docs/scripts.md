# Scripts

`scripts/` contains installer, config, ops, system, desktop, WSL, and maintenance helpers.

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

- Check binary/version before downloading; reinstall only when `FORCE=true`.
- Use `cmd_exist`, `pkg_install`, `installPackages`, and `gh_latest_release` when possible.
- Support `ubuntu`, `debian`, `linuxmint`, `arch`, `centos`; support macOS for developer tools when practical.
- Do not assume interactive-shell PATH setup; source needed `env/*.sh` files.

## Validation

See [testing.md](testing.md). Add `make test-init` for installer/bootstrap behavior. Use `make test-inst-opencode`, `make test-inst-picom`, `make lint`, or `make test-lint` when relevant. Announce Docker or UI tests before running them.
