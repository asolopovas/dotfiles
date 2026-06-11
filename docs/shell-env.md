# Shell environment

Bash and fish share paths, aliases, and helpers through repo-managed files.

## Load order

Interactive Bash: `.bashrc` -> `globals.sh` -> `env/env-vars.sh` -> `env/include-paths.sh` -> optional `env/oh-my-bash.sh` -> completions/fzf -> `.paths` -> `~/.config/.aliasrc` -> toolchain envs.

`.profile` runs at login; `.bashrc` runs for each interactive shell.

| Put | In |
|---|---|
| Environment variables | `env/env-vars.sh` |
| Shared PATH entries | `.paths` |
| Bash-only PATH entries | `env/include-paths.sh` |
| Shell-neutral aliases | `~/.config/.aliasrc` |

## `globals.sh`

Source before shared helpers.

| Group | Names |
|---|---|
| Platform | `detect_os`, `detect_arch`, `OS`, `ARCH` |
| Commands/output | `cmd_exist`, `require_cmd`, `print_color` |
| Packages | `installPackages`, `pkg_install`, `removePackage`, `hold_packages`, `unhold_packages` |
| Env/PATH | `add_paths_from_file`, `load_env_vars`, `load_env`, `source_script` |
| Filesystem | `cd_up`, `create_dir`, `fix_broken_symlinks` |
| Other | `is_sudoer`, `gh_latest_release` |

## Rules

- Add shared helpers to `globals.sh` and this table.
- Keep env vars out of `.bashrc` and `.profile` unless shell-local.
- Keep shared PATH in `.paths`.
- Use cached `OS`/`ARCH`; support the OS matrix in [../AGENTS.md](../AGENTS.md).
