## Shell Environment

### Load order (bash)

`.bashrc` → `globals.sh` → `env/env-vars.sh` → `env/include-paths.sh` → optional `env/oh-my-bash.sh` → `completions/bash/*.sh` → fzf scripts → `.paths` → `~/.config/.aliasrc` → toolchain envs (cargo, deno, nvm, pnpm, sdkman, bun, volta).

`.profile` runs once at login; `.bashrc` runs per interactive shell. Don't duplicate exports across them — put env in `env/env-vars.sh`, paths in `.paths` or `env/include-paths.sh`.

### globals.sh helpers (cheat sheet)

| Helper | Purpose |
|---|---|
| `detect_os` / `detect_arch` | Cross-platform ID from `/etc/os-release` or `uname` |
| `OS`, `ARCH` (exported) | Cached at source time, override via env |
| `cmd_exist <name>` | `command -v` wrapper |
| `print_color <color> <msg>` | ANSI-coloured output (`red`, `green`, `bold_blue`, `underline_cyan`, …) |
| `installPackages <pkgs...>` | apt/yum/pacman switch |
| `pkg_install` | Same + brew/dnf, uses `${SUDO:-}` |
| `removePackage`, `hold_packages`, `unhold_packages` | apt-mark wrappers (no-op on non-deb) |
| `is_sudoer` | Cached `sudo -v` check |
| `add_paths_from_file <file>` | One PATH entry per line (absolute or `$HOME`-relative) |
| `load_env_vars <file>` | `KEY=VAL` parser, only sets if not already set |
| `load_env <file>` | `set -a; source; set +a` for full env file |
| `cd_up <n>` | `cd ../../..` shortcut |
| `create_dir <path>` | `mkdir -p` with green log |
| `fix_broken_symlinks <dir> [--recursive]` | Removes dangling symlinks |
| `gh_latest_release owner/repo [--keep-v]` | Latest release tag from GitHub API |
| `require_cmd <cmd> <inst-script>` | Prompt to install missing dep |
| `source_script <name>` | Source `$DOTFILES/env/<name>.sh` |

### env/ directory

| File | Contents |
|---|---|
| `env-vars.sh` | Editor, locale, history, XDG vars, browser, etc. |
| `include-paths.sh` | Hardcoded PATH additions (system-wide) |
| `theme.sh` | Theme/colorscheme env (sourced by xmonad/polybar) |
| `xmonad-vars.sh` | Xmonad-specific env (modkey, fonts) |
| `oh-my-bash.sh` | Only sourced when `OHMYBASH=true` |

### Conventions

- Source order matters: `globals.sh` always first (provides `cmd_exist`, `OS`, etc.).
- New shared functions go in `globals.sh` with a short usage comment above the function.
- New env exports → `env/env-vars.sh`, not `.bashrc` / `.profile`.
- New PATH entries → `.paths` (one per line) so both bash and fish pick them up.
- Aliases → `~/.config/.aliasrc` (shared between shells where possible).
