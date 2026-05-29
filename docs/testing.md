# Testing

Use `make` targets first. Run full local validation once: `make test` when not committing, or pre-commit when committing.

## Local targets

| Target | Scope |
|---|---|
| `make test` | Local Bats suites through `tests/run-tests.sh` |
| `./tests/run-tests.sh -f "pattern"` | Filter by test name |
| `make test-globals` | `globals.sh` |
| `make test-scripts` | Script syntax and smoke checks |
| `make test-sync-ai` | AI sync |
| `make test-inst-opencode` | OpenCode installer |
| `make test-inst-picom` | Picom installer |
| `make test-lint` | Lightweight lint hygiene |
| `make lint` | External shell/fish lint tools |

`make test` installs deps when possible, parallelizes when `parallel` or `rush` exists, and caches successful suites in `.git/pi-bats-cache`; set `BATS_CACHE=0` to force reruns. Pre-commit maps changed files to affected local suites.

## Docker and UI

| Target | Use |
|---|---|
| `make test-bootstrap` | Build/update bootstrapped Docker snapshot |
| `make test-init` | Run Docker integration tests |
| `make test-init-shell` | Open Docker debug shell |
| `make test-init-rebuild` | Rebuild, then test |
| `make test-init-clean` | Remove Docker test images |
| `make test-ui-snap-window` | Run X11 snap-window tests |

Docker suites cover NAS mounts, Plesk, standard user bootstrap, vhosts, installers, and terminal toggles. UI tests require X11, `xdotool`, `wmctrl`, `xrandr`; they move real windows and may need sudo.

## Lint

`make lint` runs `shellcheck -x -S warning`, `shfmt -i 4 -ci -d`, and `fish_indent --check`. Install tools with `make install-lint-tools`. Use `make test-lint` when missing tools should skip.

## Handoff

- Add `make test-init` for bootstrap, globals, symlink, or installer behavior.
- Add `make test-ui-snap-window` for window-manager or snap-window behavior.
- Run `make lint` when lint tools exist and shell/fish formatting changed.
- Report commands, results, skipped layers, and state effects.
