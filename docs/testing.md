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

UI tests require X11, `xdotool`, `wmctrl`, `xrandr`; they move real windows and may need sudo.

## Routing

| Change | Check |
|---|---|
| Docs only | Pre-commit, or `make test` when not committing |
| `docs/help.md` | `DOTFILES="$PWD" scripts/gen-help`, then inspect diff |
| Bootstrap, globals, symlinks, installers | Local target plus `make test-init` |
| Xmonad, windows, keybindings | Local target plus `make test-ui-snap-window` |
| Shell/fish formatting | `make lint` when tools exist; otherwise `make test-lint` |
| UI/runtime | Before/after evidence, console/log output, rerun after restart |
