# Documentation index

The repo is the source of truth. Put each durable fact in one file, link to it elsewhere, and validate docs with local checks.

## Map

| Topic | Source |
|---|---|
| Agent invariants and workflow | [../AGENTS.md](../AGENTS.md) |
| Bootstrap/install flow | [bootstrap.md](bootstrap.md) |
| Tests, lint, handoff checks | [testing.md](testing.md) |
| Shell load order, helpers | [shell-env.md](shell-env.md) |
| Script naming, installer contract | [scripts.md](scripts.md) |
| AI CLI skill/config sync | [ai-sync.md](ai-sync.md) |
| Generated F1 help | [help.md](help.md) |
| Execution-plan debt | [exec-plans/tech-debt-tracker.md](exec-plans/tech-debt-tracker.md) |

## Rules

- `README.md` is the human landing page; `AGENTS.md` is the agent map.
- Topic docs own details; avoid duplicate procedures.
- Complex work gets a plan under `exec-plans/active/`; move finished plans to `exec-plans/completed/` and durable debt to the tracker.
- Generated docs must name their generator; edit the generator, not the artifact.
- Behavior changes should update docs, tests, or lint so agents can rediscover the rule.

## Validation

| Change | Check |
|---|---|
| Docs only | Pre-commit, or `make test` when not committing |
| `docs/help.md` | `DOTFILES="$PWD" scripts/gen-help`, then inspect diff |
| Bootstrap, globals, installers | Above plus `make test-init` |
| Xmonad/window/keybindings | Above plus `make test-ui-snap-window` |
| Shell lint/formatting | `make lint` when tools exist |
