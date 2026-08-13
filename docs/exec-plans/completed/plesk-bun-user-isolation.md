# Plesk Bun user isolation

## Goal

Run the global Bun binary as each calling Plesk user with private per-user caches and a safe multi-user Node shim.

## Scope

- Inventory the live Bun wrappers, sudo policy, cache, shims, vhost users, generated artifacts, and Docker access.
- Back up and replace the live wrapper without changing `bun-bin`.
- Remove obsolete shared-cache and sudo configuration while retaining rollback helpers.
- Normalize every current and future Bun Node shim.
- Repair only root-owned generated artifacts under affected projects.
- Validate Bun with at least two subscription users and Docker with `avianese`.
- Update the installer and targeted tests so bootstrap preserves the repair.

## Acceptance criteria

- `/usr/local/bin/bun` is `root:root` mode `0755`, passes `bash -n`, and directly execs `bun-bin` as the caller.
- Per-user Bun caches resolve beneath each caller's home with mode `0700`.
- No active sudoers rule permits `bun-run`, and the backup helper is not called by the wrapper.
- Every `/tmp/bun-node-*` directory is `root:root` mode `1777` with canonical root-owned links to `bun-bin`.
- Only root-owned generated project artifacts are reassigned to their Plesk subscription owner.
- `avianese` and another subscription user pass Bun validation without root-owned outputs or root Bun processes.
- Docker access remains limited to the separately approved `avianese` membership.

## Progress

- Confirmed Bun 1.3.14, a sudo-delegating wrapper, a root-running helper, one mode `0755` shim directory, and a root-owned shared cache.
- Backed up and replaced the live wrapper, retired the helper, sudo rule, and shared-cache profile, and normalized the live shim.
- Reassigned 19,133 root-owned generated entries across ten artifact roots to six derived subscription owners.
- Validated Bun as `avianese` and `bloomsart`, including private caches, effective UIDs, project ownership, shim access, sticky deletion isolation, and absence of root Bun processes.
- Added only `avianese` to Docker access and validated a fresh login against the Docker daemon.
- Updated the installer, integration assertions, bootstrap documentation, and Plesk operational reference.

## Decisions

- Preserve live rollback copies before changing wrappers or sudo policy.
- Keep the shared cache intact but inactive until validation determines whether it can be retired separately.
- Materialize a version-specific shim with `bun-bin --bun run true` before normalizing it.

## Validation

- `bash -n scripts/plesk-init.sh` and `git diff --check` passed.
- `make test-lint` passed all seven checks with `shfmt` skipped because it is not installed.
- `make test-bootstrap && make test-init` passed all three integration suites after the shim materialization assertion exposed and verified the update invocation.
- Both live users returned Bun 1.3.14 and oxlint 1.78.0 from owned projects with zero root-owned entries before and after.
- The final generated-artifact scan across all 14 subscription roots found no remaining root-owned candidate.

## Debt

- The inactive 21 GB `/var/www/bun-cache` remains `root:root` mode `2755`; removal was outside this repair because it is destructive and no active Bun configuration references it.
- `shfmt` is not installed on the host, so the lint suite skipped that formatter.
