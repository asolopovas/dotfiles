# Testing

Use `make` targets as the stable interface. Drop to runner scripts only for filters or debugging.

## Local fast tests

`make test` runs `install-test-deps`, auto-installs Bats on apt/brew systems, then runs `tests/run-tests.sh` with the default suite list.

| Suite | Scope |
|---|---|
| `test-globals.bats` | `globals.sh` helpers and OS detection |
| `test-scripts.bats` | Script syntax and behavior smoke checks |
| `test-init.bats` | `init.sh` arg parsing and feature flags |
| `test-sync-ai.bats` | AI skill/config sync behavior |
| `test-inst-opencode.bats` | OpenCode installer paths |
| `test-lint.bats` | Lightweight lint hygiene, skipping missing tools |

Focused targets:

| Target | Scope |
|---|---|
| `make test-globals` | `test-globals.bats` |
| `make test-scripts` | `test-scripts.bats` |
| `make test-sync-ai` | `test-sync-ai.bats` |
| `make test-inst-opencode` | `test-inst-opencode.bats` |
| `make test-inst-picom` | `test-inst-picom.bats` |
| `make test-lint` | `test-lint.bats` |

Filter by test name with `./tests/run-tests.sh -f "pattern"`.

## Docker bootstrap tests

`make test-init` runs Docker integration tests through `tests/run-init-tests.sh`.

| Image | Purpose |
|---|---|
| `dotfiles-base` | Heavy dependencies and mock Plesk environment |
| `dotfiles-bootstrapped` | Base image plus full `init.sh` for `stduser` and `plesk` users |
| `dotfiles-test-run` | Ephemeral runner that mounts the current repo and runs Bats |

Useful targets:

| Target | Use |
|---|---|
| `make test-bootstrap` | Build/update the bootstrapped snapshot |
| `make test-init` | Run integration tests against the current repo |
| `make test-init-shell` | Open a debug shell in the bootstrapped container |
| `make test-init-rebuild` | Rebuild then run all init tests |
| `make test-init-clean` | Remove Docker test images |

Container suites cover NAS mounts, Plesk, standard user bootstrap, vhosts, installer scripts, and terminal toggle behavior.

## UI tests

`make test-ui-snap-window` runs `tests/run-snap-tests.sh` and `test-ui-snap-window.bats`. It requires an X11 session plus `xdotool`, `wmctrl`, and `xrandr`. Some checks may require sudo. It moves and resizes real windows, so close important work first.

## Lint

`make lint` requires lint tools. Shell lint targets fail hard; fish indentation is advisory.

| Tool | Covers |
|---|---|
| `shellcheck -x -S warning` | Shell scripts selected by `Makefile` |
| `shfmt -i 4 -ci -d` | Bash formatting diff |
| `fish_indent --check` | Fish files, advisory for vendored function trees |
| `test-lint.bats` | Shebang and whitespace checks, with missing-tool skips |

Install lint tools with `make install-lint-tools`. Use `make test-lint` for the Bats lint suite that skips missing external tools.

## Pre-handoff checklist

- Run full local validation once: use `make test` when not committing, or let the pre-commit hook run it when committing.
- If `make test` already passed for the unchanged tree, the pre-commit hook skips the duplicate run.
- Add `make test-init` for bootstrap, globals, symlink, or installer behavior changes.
- Add `make test-ui-snap-window` for window-manager or snap-window behavior changes.
- Run `make lint` when lint tools are available and the change touched shell/fish formatting.
- State skipped layers and any system-state effects in the handoff.
