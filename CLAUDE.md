# CLAUDE.md
personal dotfiles repository

## Installation

main script (`init.sh`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

### Optional Environment Variables for `init.sh`:

* `BUN`, `DENO`, `FISH`, `FZF`, `NODE`, `NVIM`, `OHMYFISH`
  (`NODE_VERSION` controls Node.js version.)

## Architecture

### Core Components
* `scripts/`: Tool installation scripts (`install-{tool}.sh`)
* `helpers/`: Utility scripts (`system/`, `tools/`, `web/`)
* `.config/`: Linux config files

### Directories
* `completions/`: Shell completions (Fish, Bash)
* `helpers/{system,tools,web}/`: Organized helper utilities

## Common Commands
* **Individual Installs:** `source scripts/install-{nvim,fish,fzf}.sh`

## Key Features
* Fish with Oh My Fish, custom completions, and FZF integration
* Neovim, Tmux, Node.js, Deno, Bun
* Cross-platform support (Linux/WSL)
* Symbolic-linked configs for easy updates

## Notes
