# Shell environment

Bash and fish share paths, aliases, and helpers through repo-managed files.

## Load order

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

`.profile` runs at login; `.bashrc` runs for each interactive shell.

| Put | In |
|---|---|
| Environment variables | `env/env-vars.sh` |
| Shared PATH entries | `.paths` |
| Bash-only PATH entries | `env/include-paths.sh` |
| Shell-neutral aliases | `~/.config/.aliasrc` |

## `globals.sh`

Source `globals.sh` before using shared helpers.

| Helper group | Names |
|---|---|
| Platform | `detect_os`, `detect_arch`, `OS`, `ARCH` |
| Commands/output | `cmd_exist`, `require_cmd`, `print_color` |
| Packages | `installPackages`, `pkg_install`, `removePackage`, `hold_packages`, `unhold_packages` |
| Env/PATH | `add_paths_from_file`, `load_env_vars`, `load_env`, `source_script` |
| Filesystem | `cd_up`, `create_dir`, `fix_broken_symlinks` |
| Other | `is_sudoer`, `gh_latest_release` |

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
- Keep env vars out of `.bashrc` and `.profile` unless shell-local.
- Keep shared PATH entries in `.paths`.
- Use cached `OS`/`ARCH`; switch on `ubuntu | debian | linuxmint | arch | centos | macos`.
- Match existing shell style.
