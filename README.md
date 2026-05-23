# Dotfiles

Personal Linux desktop/server dotfiles: shell, Neovim, Xmonad, tmux, terminal tooling, AI CLI config, and bootstrap automation.

## Quick start

```bash
git clone https://github.com/asolopovas/dotfiles.git ~/dotfiles
cd ~/dotfiles
./init.sh
```

Remote bootstrap:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

`init.sh` is intentionally self-contained for `curl | bash` use. It updates existing checkouts destructively and replaces managed config paths with symlinks; see [docs/bootstrap.md](docs/bootstrap.md). Back up local changes first.

## Docs map

Start with [docs/index.md](docs/index.md). Topic docs are the source of record:

| Need | Doc |
|---|---|
| Bootstrap flags, flow, symlinks | [docs/bootstrap.md](docs/bootstrap.md) |
| Test layers and validation | [docs/testing.md](docs/testing.md) |
| Bash/fish load order and helpers | [docs/shell-env.md](docs/shell-env.md) |
| Script taxonomy and installer rules | [docs/scripts.md](docs/scripts.md) |
| AI CLI skill/config sync | [docs/ai-sync.md](docs/ai-sync.md) |
| F1 keyboard cheatsheet | [docs/help.md](docs/help.md) |

## Common commands

| Task | Command |
|---|---|
| Install/update this environment | `./init.sh` or `make install` |
| Skip selected tools | `NODE=false FISH=false ./init.sh` |
| Force reinstall managed tools | `FORCE=true ./init.sh` |
| Opt into cargo | `CARGO=true ./init.sh` |
| Keep the current login shell | `CHANGE_SHELL=false ./init.sh` |
| Run local fast tests | `make test` |
| Run Docker bootstrap tests | `make test-init` |
| Run X11 window tests | `make test-ui-snap-window` |
| Regenerate F1 help | `DOTFILES="$PWD" scripts/gen-help` |

Full feature flag table: [docs/bootstrap.md#feature-flags](docs/bootstrap.md#feature-flags).

## Repository layout

```text
init.sh              Curl-safe bootstrap entrypoint
globals.sh           Shared shell library
autostart.sh         Desktop autostart
Makefile             Test, lint, and utility targets
scripts/             Install, config, ops, system, UI, and WSL scripts
helpers/             Small CLI wrappers installed on PATH
env/                 Shared shell environment fragments
completions/         Bash and fish completions
conf.d/              System config snippets
fzf/                 fzf options, keybindings, exclusions
.config/             Application configs
tests/               Bats suites and Docker/X11 runners
docs/                Source-of-record documentation
```
