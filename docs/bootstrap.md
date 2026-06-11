# Bootstrap

`init.sh` installs or updates the repo from a cold machine and must stay curl-safe before `globals.sh` exists.

## Commands

| Goal | Command |
|---|---|
| Default | `./init.sh` |
| Remote | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"` |
| Skip common tools | `NODE=false FISH=false ./init.sh` or `./init.sh --no-node --no-fish` |
| Force reinstall | `FORCE=true ./init.sh` or `./init.sh --force` |
| SSH remote | `./init.sh --type=ssh` |
| Keep shell | `CHANGE_SHELL=false ./init.sh` |

## Flags

| Flag | Default | Purpose |
|---|---|---|
| `BUN`, `DENO`, `NODE`, `NVIM`, `FISH`, `FZF`, `FDFIND`, `OHMYFISH` | `true` | Standard tools |
| `OHMYBASH`, `OHMYZSH`, `ZSH`, `CARGO` | `false` | Opt-in tools |
| `CHANGE_SHELL`, `UNATTENDED` | `true` | Fish switch, menu skip |
| `FORCE`, `SYSTEM` | `false` | Reinstall cleanup, desktop/system links |
| `TYPE`, `NODE_VERSION` | `https`, `24.13.0` | Git remote, Node version |

CLI `--no-*` only covers `fish`, `node`, `bun`, `deno`, and `nvim`.

## Flow

1. Define helpers, detect `OS`/`ARCH`, parse args, export flags.
2. Ensure base tools/dirs; clean managed installs when `FORCE=true`.
3. Clone or reset `$DOTFILES_DIR`; preserve shared `/opt/dotfiles` Plesk checkouts.
4. On root Plesk hosts, run `scripts/plesk-init.sh` and exit.
5. Load composer installer, optional menu, `globals.sh`, and `scripts/cfg-default-dirs.sh`.
6. Link configs, install enabled tools via `ensure_tool`, apply desktop and shell side effects.

Installer requirements: [scripts.md](scripts.md#installer-contract). Validation routing: [testing.md](testing.md).
