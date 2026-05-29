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

`init.sh` resets existing checkouts and replaces managed config paths with symlinks. Back up local changes first. See [docs/bootstrap.md](docs/bootstrap.md).

## Commands

| Task | Command |
|---|---|
| Install/update | `./init.sh` or `make install` |
| Skip tools | `NODE=false FISH=false ./init.sh` |
| Force reinstall | `FORCE=true ./init.sh` |
| Keep login shell | `CHANGE_SHELL=false ./init.sh` |
| Validate | `make test` |
| Regenerate F1 help | `DOTFILES="$PWD" scripts/gen-help` |

Start with [AGENTS.md](AGENTS.md) for invariants and [docs/index.md](docs/index.md) for docs and checks.
