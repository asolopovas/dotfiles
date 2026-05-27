# Dotfiles

Personal Linux desktop/server dotfiles for shell, Neovim, Xmonad, tmux, terminals, AI CLIs, and bootstrap automation.

## Install

```bash
git clone https://github.com/asolopovas/dotfiles.git ~/dotfiles
cd ~/dotfiles
./init.sh
```

Remote bootstrap:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

`init.sh` is curl-safe, updates existing checkouts destructively, and replaces managed config paths with symlinks. Back up local changes first. See [docs/bootstrap.md](docs/bootstrap.md).

## Docs

| Need | Doc |
|---|---|
| Docs index and validation map | [docs/index.md](docs/index.md) |
| Bootstrap flags, flow, symlinks | [docs/bootstrap.md](docs/bootstrap.md) |
| Tests and handoff checks | [docs/testing.md](docs/testing.md) |
| Bash/fish load order and helpers | [docs/shell-env.md](docs/shell-env.md) |
| Script taxonomy and installer rules | [docs/scripts.md](docs/scripts.md) |
| AI CLI skill/config sync | [docs/ai-sync.md](docs/ai-sync.md) |
| F1 keyboard cheatsheet | [docs/help.md](docs/help.md) |

## Commands

| Task | Command |
|---|---|
| Install/update | `./init.sh` or `make install` |
| Skip tools | `NODE=false FISH=false ./init.sh` |
| Force reinstall | `FORCE=true ./init.sh` |
| Opt into cargo | `CARGO=true ./init.sh` |
| Keep login shell | `CHANGE_SHELL=false ./init.sh` |
| Local tests | `make test` |
| Bootstrap tests | `make test-init` |
| X11 window tests | `make test-ui-snap-window` |
| Regenerate F1 help | `DOTFILES="$PWD" scripts/gen-help` |

## Layout

```text
init.sh       Curl-safe bootstrap
globals.sh    Shared shell library
Makefile      Test, lint, install, utility targets
scripts/      Install, config, ops, system, UI, WSL scripts
helpers/      CLI wrappers installed on PATH
env/          Shared environment fragments
completions/  Bash/fish completions
conf.d/       System config snippets
fzf/          fzf options, keybindings, exclusions
.config/      Application configs
tests/        Bats, Docker, X11 tests
docs/         Source-of-record docs
```
