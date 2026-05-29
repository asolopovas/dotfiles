# Testing

Run the same checks locally that CI and hooks run. Use `make` targets first.

## Local

| Target | Scope |
|---|---|
| `make test` | Default Bats suites |
| `./tests/run-tests.sh -f "pattern"` | Filter by test name |
| `make test-globals` | `globals.sh` |
| `make test-scripts` | Script syntax and smoke checks |
| `make test-sync-ai` | AI sync |
| `make test-inst-opencode` | OpenCode installer |
| `make test-inst-picom` | Picom installer |
| `make test-lint` | Lint hygiene with skips for missing tools |
| `make lint` | Shellcheck, shfmt, fish_indent |

`make test` installs deps when possible, parallelizes with `parallel` or `rush`, and caches passing suites in `.git/pi-bats-cache`; set `BATS_CACHE=0` to force reruns. Pre-commit maps changed files to affected suites.

## Docker and UI

| Target | Scope |
|---|---|
| `make test-bootstrap` | Build/update Docker snapshot |
| `make test-init` | Bootstrap integration tests |
| `make test-init-shell` | Docker debug shell |
| `make test-init-rebuild` | Rebuild, then test |
| `make test-init-clean` | Remove Docker images |
| `make test-ui-snap-window` | X11 snap-window tests |

Announce Docker or UI targets before running. UI tests require X11, `xdotool`, `wmctrl`, `xrandr`; they move real windows and may need sudo.

## Routing

- Bootstrap, globals, symlinks, installers: local target plus `make test-init`.
- Window manager or snap-window behavior: local target plus `make test-ui-snap-window`.
- Shell/fish formatting: `make lint` when tools exist, otherwise `make test-lint`.
- UI/runtime changes: capture before/after evidence, console/log output when relevant, and rerun after restart.

Report commands, results, skipped layers, state effects, and follow-up debt.
