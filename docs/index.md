# Documentation index

This directory is the repository knowledge base. Keep entry points compact, put detailed facts in the topic doc that owns them, and prefer links over duplicated tables.

## Start here

| Topic | Source of record |
|---|---|
| Bootstrap/install flow | [bootstrap.md](bootstrap.md) |
| Tests, lint, and handoff checks | [testing.md](testing.md) |
| Shell load order and shared helpers | [shell-env.md](shell-env.md) |
| Script naming and installer conventions | [scripts.md](scripts.md) |
| AI CLI skill/config sync | [ai-sync.md](ai-sync.md) |
| Desktop F1 keyboard help | [help.md](help.md) |

## Documentation rules

- `README.md` is the human landing page.
- `AGENTS.md` is the agent map and invariant list.
- Topic docs own details; update the owner instead of copying facts across files.
- Link to code when behavior matters, then validate against tests or `make help`.
- Keep generated surfaces generated. `docs/help.md` comes from `scripts/gen-help`.

## Validation map

| Change | Minimum check |
|---|---|
| Docs only | Pre-commit, or `make test` when not committing |
| Bootstrap, `init.sh`, `globals.sh`, installers | Pre-commit, or `make test` when not committing; add `make test-init` |
| Xmonad/window/keybinding behavior | Pre-commit, or `make test` when not committing; add `make test-ui-snap-window` |
| `docs/help.md` content | `DOTFILES="$PWD" scripts/gen-help` then inspect `git diff` |
| Shell formatting or lint rules | `make lint` when tools are installed |
