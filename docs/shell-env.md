# Shell environment

Bash and fish share paths, aliases, and helpers through repo-managed files.

## Bash load order

Interactive Bash loads:

```text
.bashrc
globals.sh
env/env-vars.sh
env/include-paths.sh
env/oh-my-bash.sh when enabled
completions/bash/*.sh
fzf scripts
.paths
~/.config/.aliasrc
toolchain envs
```

`.profile` runs at login. `.bashrc` runs for each interactive shell.

| Put | In |
|---|---|
| Environment variables | `env/env-vars.sh` |
| PATH entries for Bash and fish | `.paths` |
| Bash-only PATH entries | `env/include-paths.sh` |
| Shell-neutral aliases | `~/.config/.aliasrc` |

## `globals.sh`

Source `globals.sh` before using shared helpers.

| Helper | Purpose |
|---|---|
| `detect_os`, `detect_arch` | OS/arch detection |
| `OS`, `ARCH` | Exported cached detection |
| `cmd_exist <name>` | `command -v` wrapper |
| `print_color <color> <msg>` | Colored output |
| `installPackages <pkgs...>` | apt/yum/pacman switch |
| `pkg_install <pkgs...>` | brew/dnf-aware install wrapper |
| `removePackage` | Remove packages |
| `hold_packages`, `unhold_packages` | Debian package holds |
| `is_sudoer` | Cached sudo check |
| `add_paths_from_file <file>` | Add PATH entries from a file |
| `load_env_vars <file>` | Load `KEY=VAL` without overriding existing values |
| `load_env <file>` | Export variables from a sourced env file |
| `cd_up <n>` | Move up directories |
| `create_dir <path>` | `mkdir -p` with logging |
| `fix_broken_symlinks <dir> [--recursive]` | Remove dangling symlinks |
| `gh_latest_release owner/repo [--keep-v]` | Get latest GitHub release tag |
| `require_cmd <cmd> <inst-script>` | Prompt to install a dependency |
| `source_script <name>` | Source `$DOTFILES/env/<name>.sh` |

## `env/`

| File | Contents |
|---|---|
| `env-vars.sh` | Editor, locale, history, XDG, browser, shared tool settings |
| `include-paths.sh` | Hardcoded PATH additions |
| `theme.sh` | Desktop theme variables |
| `xmonad-vars.sh` | Xmonad modkey, fonts, UI variables |
| `oh-my-bash.sh` | Oh My Bash setup when enabled |

## Rules

- Add shared functions to `globals.sh` and this helper table.
- Keep env vars out of `.bashrc` and `.profile` unless they must be shell-local.
- Keep shared PATH entries in `.paths`.
- Match existing shell style; do not add `set -euo pipefail` to legacy scripts only because you touched them.
