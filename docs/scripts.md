# Scripts

`scripts/` contains executable maintenance, installer, system, and desktop helpers. Keep scripts idempotent, OS-aware, and easy for agents to classify by name.

## Naming

Use `{prefix}-{name}.sh` under the matching category directory when one exists.

| Prefix | Use |
|---|---|
| `inst-` | Install one tool, runtime, package group, or service |
| `cfg-` | Configure a local/system setting |
| `ops-` | Operate or maintain existing services/data |
| `sec-` | Security, certificates, permissions, keyrings |
| `sys-` | System fixes, kernel, drivers, limits |
| `ui-` | Desktop, window manager, displays, panels |
| `wsl-` | WSL and Windows interop |

Standalone executables installed into `~/.local/bin` may omit `.sh` when the command name is the user-facing interface.

## Installer contract

`inst-*.sh` scripts are sourced from `init.sh`, so they share exported feature flags and helpers after `globals.sh` is loaded.

- Check for the binary or installed version before downloading.
- Reinstall only when `FORCE=true`.
- Use `cmd_exist`, `pkg_install`, `installPackages`, and `gh_latest_release` from `globals.sh` where applicable.
- Support `ubuntu`, `debian`, `linuxmint`, `arch`, `centos`, and macOS for developer-tool installers when practical.
- Do not assume PATH setup from an interactive shell; source the relevant `env/*.sh` file when needed.

## Validation

| Change | Check |
|---|---|
| Any shell script | Pre-commit, or `make test` when not committing |
| Installer/bootstrap behavior | Pre-commit, or `make test` when not committing; add `make test-init` |
| `inst-opencode.sh` | `make test-inst-opencode` |
| `inst-picom.sh` | `make test-inst-picom` |
| Shell lint/formatting | `make lint` or `make test-lint` |

Docker and UI tests can mutate system state or take focus. Announce them before running outside the normal foreground workflow.
