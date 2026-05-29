# Bootstrap

`init.sh` installs or updates this repo from a cold machine and must stay curl-safe before `globals.sh` exists.

## Commands

| Goal | Command |
|---|---|
| Default install | `./init.sh` |
| Remote install | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"` |
| Skip tools | `NODE=false FISH=false ./init.sh` or `./init.sh --no-node --no-fish` |
| Force reinstall | `FORCE=true ./init.sh` or `./init.sh --force` |
| SSH remote | `./init.sh --type=ssh` |
| Keep login shell | `CHANGE_SHELL=false ./init.sh` |

## Flags

| Flag | Default | Purpose |
|---|---|---|
| `BUN`, `DENO`, `NODE`, `NVIM`, `FISH`, `FZF`, `FDFIND`, `OHMYFISH` | `true` | Standard tools |
| `OHMYBASH`, `OHMYZSH`, `ZSH`, `CARGO` | `false` | Opt-in tools |
| `CHANGE_SHELL`, `UNATTENDED` | `true` | Fish shell switch, menu skip |
| `FORCE`, `SYSTEM` | `false` | Reinstall cleanup, desktop/system links |
| `TYPE`, `NODE_VERSION` | `https`, `24.13.0` | Git remote type, Node version |

CLI `--no-*` exists only for `fish`, `node`, `bun`, `deno`, and `nvim`; use env vars for other toggles.

## Flow

1. Define helpers, detect `OS`/`ARCH`, parse args, export flags.
2. Ensure base tools/dirs; clean managed installs when `FORCE=true`.
3. Clone or reset `$DOTFILES_DIR`, except shared `/opt/dotfiles` Plesk checkouts.
4. On root Plesk hosts, run `scripts/plesk-init.sh` and exit.
5. Load composer installer, optional menu, `globals.sh`, and `scripts/cfg-default-dirs.sh`.
6. Link configs; install enabled tools through `ensure_tool`; apply supported desktop side effects and shell switch.

## Installer contract

- Check binary/version before downloading; reinstall only when `FORCE=true`.
- After `globals.sh`, use `installPackages` or `pkg_install`.
- Prefer `gh_latest_release owner/repo`; source needed `env/*.sh` before relying on PATH changes.

## Validation

See [testing.md](testing.md). Add `make test-init` for `init.sh`, `globals.sh`, `cfg-default-dirs.sh`, or `inst-*.sh`. Use `make test-inst-opencode` or `make test-inst-picom` for focused installer checks.
