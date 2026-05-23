# Shell environment

Bash and fish share paths, aliases, and helper behavior through repo-managed files. Keep exports centralized so login shells, interactive shells, and installer scripts agree.

## Bash load order

Interactive Bash loads in this order:

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

`.profile` runs once at login. `.bashrc` runs for each interactive shell. Put environment variables in `env/env-vars.sh`, PATH entries in `.paths` or `env/include-paths.sh`, and shared aliases in `~/.config/.aliasrc`.

## `globals.sh` helpers

| Helper | Purpose |
|---|---|
| `detect_os`, `detect_arch` | Cross-platform OS/arch detection |
| `OS`, `ARCH` | Exported cached detection results |
| `cmd_exist <name>` | `command -v` wrapper |
| `print_color <color> <msg>` | ANSI-colored output helper |
| `installPackages <pkgs...>` | apt/yum/pacman package install switch |
| `pkg_install <pkgs...>` | Package install wrapper with brew/dnf support and `${SUDO:-}` |
| `removePackage`, `hold_packages`, `unhold_packages` | Package removal plus Debian-focused hold/unhold helpers |
| `is_sudoer` | Cached sudo availability check |
| `add_paths_from_file <file>` | Add one PATH entry per line |
| `load_env_vars <file>` | Parse `KEY=VAL` without overriding existing values |
| `load_env <file>` | Export all variables from a sourced env file |
| `cd_up <n>` | Move up `n` directories |
| `create_dir <path>` | `mkdir -p` with logging |
| `fix_broken_symlinks <dir> [--recursive]` | Remove dangling symlinks |
| `gh_latest_release owner/repo [--keep-v]` | Read latest GitHub release tag |
| `require_cmd <cmd> <inst-script>` | Prompt to install a missing dependency |
| `source_script <name>` | Source `$DOTFILES/env/<name>.sh` |

## `env/` files

| File | Contents |
|---|---|
| `env-vars.sh` | Editor, locale, history, XDG vars, browser, shared tool settings |
| `include-paths.sh` | Hardcoded PATH additions |
| `theme.sh` | Theme/colorscheme variables for desktop components |
| `xmonad-vars.sh` | Xmonad modkey, fonts, and UI variables |
| `oh-my-bash.sh` | Oh My Bash setup when `OHMYBASH=true` |

## Conventions

- Source `globals.sh` before relying on shared helpers.
- Add new shared functions to `globals.sh` and update the helper table here.
- Add new environment variables to `env/env-vars.sh`, not `.bashrc` or `.profile`.
- Add new PATH entries to `.paths` when both Bash and fish should see them.
- Keep aliases in `~/.config/.aliasrc` when they are shell-neutral.
- Match existing shell style; do not add `set -euo pipefail` to legacy scripts only because you touched them.
