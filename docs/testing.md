# Testing

Use `make` targets first. Use runner scripts for filters and debugging.

## Local tests

`make test` installs test deps when possible, then runs `tests/run-tests.sh`. Bats suites run in parallel when `parallel` or `rush` exists. Successful suites are cached under `.git/pi-bats-cache`; set `BATS_CACHE=0` to force reruns. The pre-commit hook maps changed files to affected local suites and skips unrelated suites.

| Suite | Scope |
|---|---|
| `test-globals.bats` | `globals.sh` helpers and OS detection |
| `test-scripts.bats` | Script syntax and smoke checks |
| `test-init.bats` | `init.sh` args and feature flags |
| `test-sync-ai.bats` | AI sync behavior |
| `test-inst-opencode.bats` | OpenCode installer |
| `test-lint.bats` | Lightweight lint hygiene |

| Target | Scope |
|---|---|
| `make test-globals` | globals suite |
| `make test-scripts` | scripts suite |
| `make test-sync-ai` | AI sync suite |
| `make test-inst-opencode` | OpenCode installer suite |
| `make test-inst-picom` | Picom installer suite |
| `make test-lint` | Bats lint suite |

Filter by test name:

```bash
./tests/run-tests.sh -f "pattern"
```

## Docker bootstrap tests

`make test-init` runs Docker integration tests through `tests/run-init-tests.sh`.

| Image | Purpose |
|---|---|
| `dotfiles-base` | Heavy deps and mock Plesk environment |
| `dotfiles-bootstrapped` | Full `init.sh` snapshot for `stduser` and `plesk` users |
| `dotfiles-test-run` | Ephemeral runner mounting the current repo |

| Target | Use |
|---|---|
| `make test-bootstrap` | Build/update bootstrapped snapshot |
| `make test-init` | Run integration tests |
| `make test-init-shell` | Open debug shell |
| `make test-init-rebuild` | Rebuild, then test |
| `make test-init-clean` | Remove Docker test images |

Container suites cover NAS mounts, Plesk, standard user bootstrap, vhosts, installers, and terminal toggle behavior.

## UI tests

`make test-ui-snap-window` runs `tests/run-snap-tests.sh` and `test-ui-snap-window.bats`. Requirements: X11, `xdotool`, `wmctrl`, `xrandr`; some checks may need sudo. It moves real windows.

## Lint

`make lint` requires lint tools. Shell lint fails hard; fish indentation is advisory.

| Tool | Covers |
|---|---|
| `shellcheck -x -S warning` | Shell scripts selected by `Makefile` |
| `shfmt -i 4 -ci -d` | Bash formatting diff |
| `fish_indent --check` | Fish files |
| `test-lint.bats` | Shebang and whitespace checks |

Install lint tools with `make install-lint-tools`. Use `make test-lint` when missing external tools should skip.

## Handoff

- Run full local validation once: `make test` when not committing, or pre-commit when committing.
- Add `make test-init` for bootstrap, globals, symlink, or installer behavior.
- Add `make test-ui-snap-window` for window-manager or snap-window behavior.
- Run `make lint` when lint tools exist and shell/fish formatting changed.
- State skipped layers and system-state effects.
