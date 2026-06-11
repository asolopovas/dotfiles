# Documentation index

The repo is the source of truth. Store each durable fact once, link to it, and enforce repeated guidance with tests, generators, or lint.

## Map

| Topic | Source |
|---|---|
| Agent invariants and loop | [../AGENTS.md](../AGENTS.md) |
| Bootstrap/install flow | [bootstrap.md](bootstrap.md) |
| Tests, lint, handoff | [testing.md](testing.md) |
| Shell load order, helpers | [shell-env.md](shell-env.md) |
| Script names and contracts | [scripts.md](scripts.md) |
| AI CLI sync | [ai-sync.md](ai-sync.md) |
| Generated F1 help | [help.md](help.md) |
| Follow-up debt | [exec-plans/tech-debt-tracker.md](exec-plans/tech-debt-tracker.md) |

## Rules

- `README.md` is the human landing page; `AGENTS.md` is the short agent map.
- Topic docs own details; links replace duplicated procedures.
- Complex or risky work gets `exec-plans/active/<name>.md`; completed plans move to `exec-plans/completed/`.
- Generated docs name their generator; edit the generator, then regenerate.
- Promote repeated review feedback into docs, examples, tests, or lint.
- If a doc rule cannot be checked yet, add debt or a follow-up plan.

Validation routing lives in [testing.md](testing.md).
