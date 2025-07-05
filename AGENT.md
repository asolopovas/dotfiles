# AGENT.md - Dotfiles Repository

## Commands
- **Run tests**: `./tests/run-tests.sh` (runs all tests), `./tests/test-*.sh` (specific tests)
- **Install dotfiles**: `./init.sh` (full installation)
- **Individual installs**: `source scripts/install-{tool}.sh` (e.g., `source scripts/install-nvim.sh`)

## Architecture
- **Core**: `init.sh` (main installer), `globals.sh` (shared functions)
- **Scripts**: `scripts/` (tool installers like `install-nvim.sh`, `install-fish.sh`)
- **Helpers**: `helpers/` (utilities organized in `system/`, `tools/`, `web/`)
- **Config**: `.config/` (Linux config files), symlinked to `~/.config/`
- **Tests**: `tests/` (bash test scripts)

## Code Style
- **Shell**: Bash scripts with set -euo pipefail, use `print_color` for output
- **Functions**: snake_case naming, check existence with `cmd_exist`
- **Variables**: UPPER_CASE for globals, exported via `globals.sh`
- **Error handling**: Use `set -e` and explicit error checking
- **Paths**: Use `$DOTFILES_DIR`, `$CONFIG_DIR`, `$SCRIPTS_DIR` variables
- **Package management**: Use `installPackages` function for cross-distro support

## Features
- Cross-platform (Linux/WSL), Fish shell with Oh My Fish, Neovim, FZF integration
- Environment variables control installation: `BUN`, `DENO`, `FISH`, `FZF`, `NODE`, `NVIM`, `OHMYFISH`
