# Plesk Codex state isolation

## Goal

Provide one root-managed Codex executable to every Plesk vhost while keeping authentication, configuration, sessions, and SQLite databases writable and private per user.

## Scope

- Track the shared Codex wrapper and updater in dotfiles.
- Provision the runtime through `scripts/plesk-init.sh`.
- Remove the shared `CODEX_SQLITE_HOME` environment.
- Protect legacy shared state from vhost access.
- Provision each vhost's `.codex` directory and config ownership.
- Add local and Plesk integration checks.
- Document ownership and update behavior.

## Acceptance criteria

- Every configured vhost can execute `codex`.
- Codex resolves SQLite state to that vhost's `.codex` directory.
- No profile exports `/opt/codex/state` as writable shared state.
- `/opt/codex` runtime files are root-owned and not group-writable.
- Vhost `.codex` directories are user-owned with mode `0700`.
- Shared managed config and skills remain readable.
- Targeted shell, unit, and Plesk integration checks pass.

## Progress

- Root cause confirmed as all vhosts sharing SQLite files that were not group-writable.
- Added a root-owned runtime wrapper, privileged updater, managed config, and per-user state provisioning.
- Migrated the live host and provisioned all 14 distinct vhost users.
- Hardened bootstrap failure handling and made Docker test the current working tree and private submodule locally.
- Wired the existing Playwright CLI installer into the complete Plesk bootstrap.

## Decisions

- Share immutable executables and managed templates only.
- Use Codex's per-user `CODEX_HOME` as `CODEX_SQLITE_HOME`.
- Keep self-update privileged behind a fixed sudo helper.
- Preserve legacy state while removing vhost access.

## Validation

- `make test`: 7 of 7 suites passed, including 31 current tests.
- `make test-bootstrap && make test-init`: 3 of 3 Docker suites passed.
- ShellCheck passed at warning level and `git diff --check` passed.
- All 14 distinct live vhost users execute Codex 0.147.0 successfully.
- Live runtime is `root:root` mode `0755`, profiles and managed config contain no shared SQLite state, and legacy state is root-only.
- A live vhost Doctor check reported both queue and state SQLite databases healthy in that user's private `.codex` directory.

## Debt

- `shfmt` is not installed on the host, so the local suite skipped that formatter check.
- The live Doctor connectivity check used HTTP fallback after a WebSocket warning; SQLite initialization and integrity were unaffected.
