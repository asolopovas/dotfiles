# Bootstrap

`init.sh` installs this repo from a cold machine. It must stay curl-safe because it runs before `globals.sh` exists.

## Commands

| Goal | Command |
|---|---|
| Default install | `./init.sh` |
| Remote install | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"` |
| Skip Node and fish | `NODE=false FISH=false ./init.sh` |
| CLI skips | `./init.sh --no-node --no-fish` |
| Force reinstall/cleanup | `FORCE=true ./init.sh` or `./init.sh --force` |
| SSH git remote | `./init.sh --type=ssh` |
| Keep login shell | `CHANGE_SHELL=false ./init.sh` |

## Feature flags

Defaults live in the `features` associative array in `init.sh` and are exported.

| Flag | Default | Notes |
|---|---|---|
| `BUN`, `DENO`, `NODE`, `NVIM`, `FISH`, `FZF`, `FDFIND` | `true` | Toolchain installs |
| `OHMYFISH` | `true` | Fish plugin manager |
| `OHMYBASH`, `OHMYZSH`, `ZSH`, `CARGO` | `false` | Opt-in |
| `CHANGE_SHELL` | `true` | Run `chsh` to fish |
| `UNATTENDED` | `true` | Skip menu |
| `FORCE` | `false` | Remove managed installs first |
| `SYSTEM` | `false` | Link desktop/system configs |
| `TYPE` | `https` | `https` or `ssh` git remote |
| `NODE_VERSION` | `24.13.0` | Node installer version |

CLI `--no-*` exists only for `fish`, `node`, `bun`, `deno`, and `nvim`. Use environment variables for other toggles.

## Flow

1. Define inline helpers, detect `OS`/`ARCH`, parse args, export flags.
2. Ensure `unzip`, create base dirs, clean managed installs when `FORCE=true`.
3. Skip shared `/opt/dotfiles` user checkouts managed by Plesk.
4. Clone or reset `$DOTFILES_DIR` from `$DOTFILES_URL`.
5. On root Plesk hosts, run `scripts/plesk-init.sh`, then exit.
6. Load the composer installer, optional `inst-menu.sh`, `globals.sh`, and `scripts/cfg-default-dirs.sh`.
7. Link managed configs into the repo, including desktop configs when `SYSTEM=true`.
8. Install enabled tools through `ensure_tool`; finish Neovim and Oh My Fish setup when enabled.
9. Apply supported Linux desktop side effects: local RTC and numlock.
10. Switch the login shell to fish when `CHANGE_SHELL=true`.

## Installer rules

- Check binary/version before downloading.
- Reinstall only when `FORCE=true`.
- After `globals.sh` loads, use `installPackages` or `pkg_install`, not raw package-manager calls.
- Prefer `gh_latest_release owner/repo` over hardcoded GitHub release versions.
- Source needed `env/*.sh` files before relying on toolchain PATH changes.

## Validation

| Change | Check |
|---|---|
| Bootstrap docs only | Pre-commit, or `make test` when not committing |
| `init.sh`, `globals.sh`, `cfg-default-dirs.sh`, `inst-*.sh` | Above plus `make test-init` |
| Installer with a focused suite | `make test-inst-opencode` or `make test-inst-picom` |

`make test-init` uses Docker and can take several minutes.
