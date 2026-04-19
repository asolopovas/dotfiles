## Bootstrap (init.sh)

Self-contained installer — safe to `curl | bash` before `globals.sh` exists. Re-runs are idempotent (each `inst-*.sh` checks for prior install unless `FORCE=true`).

### Invocation

```bash
./init.sh                                    # all defaults
NODE=false FISH=false ./init.sh              # env-var feature flags
./init.sh --no-node --no-fish                # equivalent CLI flags
FORCE=true ./init.sh                         # force-reinstall everything
./init.sh --type=ssh                         # use SSH instead of HTTPS for git
```

### Feature flags

Defaults defined in the `features` assoc array near the top of `init.sh`. `--no-X` flags only exist for: `fish`, `node`, `bun`, `deno`, `nvim`. Everything else uses env vars.

| Flag | Default | Notes |
|---|---|---|
| `BUN`, `DENO`, `NODE`, `NVIM`, `FISH`, `FZF`, `FDFIND` | `true` | Toolchain installs |
| `OHMYFISH` | `true` | Fish plugin manager |
| `OHMYBASH`, `OHMYZSH`, `ZSH`, `CARGO` | `false` | Opt-in |
| `CHANGE_SHELL` | `true` | `chsh` to fish at end |
| `UNATTENDED` | `true` | Skip prompts |
| `FORCE` | `false` | Re-run installers even if already installed |
| `SYSTEM` | `false` | System-wide tweaks (mainline kernel etc.) |
| `TYPE` | `https` | `https` or `ssh` for git remotes |
| `NODE_VERSION` | `24.13.0` | Pinned via nvm |

All flags are exported so child `inst-*.sh` scripts can read them.

### Sequence

1. Bootstrap utils inlined (`cmd_exist`, `print_color`, `_detect_os`, `_detect_arch`) — cannot rely on `globals.sh` yet.
2. Parse args → set feature env vars.
3. Set up `SUDO` wrapper (no-op if root).
4. Clone/update `$DOTFILES_DIR` from `$DOTFILES_URL`.
5. Source `globals.sh`, then run `inst-*.sh` for enabled features.
6. Symlinks → `~/.config/`, fish/bash configs.
7. If `CHANGE_SHELL=true`, `chsh` to fish.

### Idempotency rules for `inst-*.sh`

- Check for the binary or version before downloading. Reinstall only if `FORCE=true`.
- Use `gh_latest_release owner/repo` from `globals.sh` instead of hardcoding versions.
- Use `installPackages` / `pkg_install` for OS-portable installs.
- Never assume `$PATH` is set up — source the relevant `env/*.sh` if needed.

### Test it

`make test-init` runs the full bootstrap inside Docker (`tests/Dockerfile.init-test`) for both `stduser` and `plesk` users. See [testing.md](testing.md).
