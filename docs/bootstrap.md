# Bootstrap

`init.sh` installs this repo from a cold machine and must stay curl-safe. It runs before `globals.sh` exists, so its inline helpers are intentional.

## Invocation

| Goal | Command |
|---|---|
| Default install | `./init.sh` |
| Remote install | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"` |
| Skip Node and fish | `NODE=false FISH=false ./init.sh` |
| Equivalent CLI skips | `./init.sh --no-node --no-fish` |
| Force reinstall/cleanup | `FORCE=true ./init.sh` or `./init.sh --force` |
| Use SSH git remote | `./init.sh --type=ssh` |
| Keep current login shell | `CHANGE_SHELL=false ./init.sh` |

## Feature flags

Defaults live in the `features` associative array in `init.sh`. All values are exported for child scripts.

| Flag | Default | Notes |
|---|---|---|
| `BUN`, `DENO`, `NODE`, `NVIM`, `FISH`, `FZF`, `FDFIND` | `true` | Toolchain installs |
| `OHMYFISH` | `true` | Fish plugin manager |
| `OHMYBASH`, `OHMYZSH`, `ZSH`, `CARGO` | `false` | Opt-in |
| `CHANGE_SHELL` | `true` | Run `chsh` to fish at the end |
| `UNATTENDED` | `true` | Skip the interactive menu |
| `FORCE` | `false` | Remove managed installs and rerun installers |
| `SYSTEM` | `false` | Link desktop/system config set |
| `TYPE` | `https` | `https` or `ssh` git remote |
| `NODE_VERSION` | `24.13.0` | Node version used by the Node installer |

CLI `--no-*` flags exist only for `fish`, `node`, `bun`, `deno`, and `nvim`. Other toggles use environment variables.

## Flow

1. Define curl-safe helpers, detect `OS`/`ARCH`, parse CLI args, and export feature flags.
2. Ensure `unzip`, create base directories, and clean managed installs when `FORCE=true`.
3. Exit early for shared `/opt/dotfiles` user checkouts managed by Plesk.
4. Clone or update `$DOTFILES_DIR` from `$DOTFILES_URL`. Existing checkouts are reset hard to `origin/main` and cleaned.
5. On root Plesk hosts, delegate to `scripts/plesk-init.sh sync` when `/opt/dotfiles` exists, otherwise `scripts/plesk-init.sh all`, then exit.
6. Load the composer installer, optionally show `inst-menu.sh`, source `globals.sh`, and source `scripts/cfg-default-dirs.sh`.
7. `cfg-default-dirs.sh` creates base directories and replaces managed config destinations with symlinks into the repo, including the extra desktop set when `SYSTEM=true`.
8. Install enabled tools through `ensure_tool`, then run Neovim and Oh My Fish setup when enabled.
9. Apply desktop side effects on supported Linux systems: local RTC for dual boot and numlock setup.
10. If `CHANGE_SHELL=true`, switch the default shell to fish.

## Idempotency rules

- Check the binary or version before downloading.
- Reinstall only when `FORCE=true`.
- Use `installPackages` or `pkg_install` instead of raw package-manager calls after `globals.sh` is available.
- Use `gh_latest_release owner/repo` instead of hardcoded GitHub release versions when possible.
- Source relevant `env/*.sh` files before relying on toolchain PATH changes.

## Validation

| Change | Check |
|---|---|
| Bootstrap docs only | Pre-commit, or `make test` when not committing |
| `init.sh`, `globals.sh`, `scripts/cfg-default-dirs.sh`, or `inst-*.sh` | Pre-commit, or `make test` when not committing; add `make test-init` |
| Individual installer with a suite | `make test-inst-opencode` or `make test-inst-picom` |

`make test-init` uses Docker and can take several minutes. It may build the bootstrap snapshot first when missing.
