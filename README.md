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

## Common commands

| Task | Command |
|---|---|
| Install/update | `./init.sh` or `make install` |
| Validate | `make test` |
| Regenerate F1 help | `DOTFILES="$PWD" scripts/gen-help` |

Install flags and variants: [docs/bootstrap.md](docs/bootstrap.md).

Agents start with [AGENTS.md](AGENTS.md). Humans start with [docs/index.md](docs/index.md).
