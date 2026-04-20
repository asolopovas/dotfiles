## Testing

Three layers, run from `make` targets. Don't invoke `bats` directly unless filtering.

### 1. Local fast tests (~2-5s) — `make test`

`tests/run-tests.sh` runs these bats suites in order (fast first):

| Suite | Scope |
|---|---|
| `test-globals.bats` | `globals.sh` helpers (OS detect, `cmd_exist`, `print_color`, etc.) |
| `test-scripts.bats` | Script syntax + behaviour smoke checks |
| `test-init.bats` | `init.sh` arg parsing, feature flags |
| `test-sync-ai.bats` | `scripts/sync-ai.sh` skill/MCP/agent sync |
| `test-inst-opencode.bats` | `inst-opencode.sh` install paths |
| `test-inst-picom.bats` | `inst-picom.sh` install paths |

Filter: `./tests/run-tests.sh -f "pattern"` or `bats tests/<file>.bats -f "name"`.

### 2. Docker integration tests — `make test-init`

Three-image strategy, all defined in `tests/`:

- `dotfiles-base` — heavy deps + mock Plesk env (cached, rebuild rare)
- `dotfiles-bootstrapped` — base + full `init.sh` for `stduser` and `plesk` users (built by `make test-bootstrap`, ~5min, committed as image)
- `dotfiles-test-run` — ephemeral container, mounts current repo, runs bats against the bootstrapped state

Workflow: `make test-bootstrap` once → `make test-init` repeatedly (<30s). `make test-init-shell` for a debug shell. `make test-init-rebuild` forces full rebuild. `make test-init-clean` wipes images.

Tests inside the container: `test-mount-nas.bats`, `test-plesk.bats`, `test-stduser.bats`, `test-vhost.bats`, `test-inst-scripts.bats`, `test-terminal-toggle.bats`.

### 3. UI tests (X11 required) — `make test-ui-snap-window`

`tests/run-snap-tests.sh` runs `test-ui-snap-window.bats`. Needs running X11 session (`xdotool`, `wmctrl`, `xrandr`). Some sub-tests need sudo. Tests will move/resize real windows — close important work first.

### Conventions

- File pattern: `tests/test-{target}.bats`
- Use `setup()` / `teardown()` for state. `skip` for missing deps. `run` to capture exit + output.
- Tests that mutate system state must be noted in PR description.
- Scripts under test must be `chmod +x`.
- Test artefacts live in `/tmp` — `make clean-tests` to remove.

### 4. Lint — `make lint`

Sanity checks for shell, fish, and shebang/whitespace hygiene. Tools auto-skip when missing in the bats suite (`test-lint.bats`) so `make test` stays green on minimal machines; `make lint` itself errors hard.

| Tool | Covers |
|---|---|
| `shellcheck -x -S warning` | All `*.sh` (excluding `node_modules`, `.git`, `tests/run-init-tests.sh`) |
| `shfmt -i 4 -ci -d` | Canonical 4-space + switch-case indent. `make lint-shell-fix` writes fixes |
| `fish_indent --check` | Advisory in `make lint-fish`. Bats only enforces a small "owned" subset (most of `functions/` is vendored: fisher, fzf, nvm, sdkman, prompt) |
| Custom bats | Forbids `#!/bin/sh`, forbids trailing whitespace |

Install: `make install-lint-tools` (runs `scripts/inst/inst-lint-tools.sh`, OS-portable).

### Pre-handoff checklist

`make test` (local fast, includes lint suite that skips on missing tools). For init/bootstrap changes also run `make test-init`. For window-manager/snap changes also run `make test-ui-snap-window`. Run `make lint` if you have the tools installed. Note any skipped layer in the handoff.
