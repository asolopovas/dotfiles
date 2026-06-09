---
name: wordpress-test-login
description: "Provision a throwaway WordPress admin and log a Playwright browser into wp-admin in one command, for authenticated UI/editor testing on local/dev sites. Use whenever a task needs a real, valid WordPress session."
group: WordPress
risk: medium
source: user-requirements
created: "2026-06-09"
---

# WordPress Test Login

**Purpose** — Get a valid, authenticated wp-admin browser session (real form login, real
`wp_rest` nonce) for `playwright-cli`, without touching real users.

**When to use** — Any task that must act as a logged-in user: editor/Gutenberg tests, admin
UI checks, REST-backed saves. Local/dev hosts only.

**Required inputs**
- WordPress path (`/path/to/wp`) on a local host (`*.test`, `*.local`, `localhost`); the script refuses others.
- `wp` (wp-cli) and `playwright-cli` on `PATH`. Without `playwright-cli` the script provisions creds only.

## Key actions

```bash
# One command: provision/rotate `pi-test-admin` (random WP password), store creds chmod 600 at
# ${XDG_DATA_HOME:-$HOME/.local/share}/wp-test-auth/<host>.env, open playwright-cli, log into
# wp-admin in the default session. Prints `Logged in -> wp-admin ready`. No secrets printed.
bash <skill_dir>/scripts/wp-test-login.sh /path/to/wordpress

# Then drive the same session:
playwright-cli goto http://<host>/wp-admin/post.php?post=<ID>&action=edit
playwright-cli snapshot --filename=/tmp/edit.yml     # YAML to the file, not stdout

# Reuse creds in a script without echoing them:
set -a; . "${XDG_DATA_HOME:-$HOME/.local/share}/wp-test-auth/<host>.env"; set +a

# Clean up when done:
playwright-cli close
wp --path=<wp> user delete pi-test-admin --reassign=1 --yes
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/wp-test-auth/<host>.env"
```

Task runner: copy `assets/justfile` (preferred) or `assets/Makefile` and run
`just wp-login path=/path/to/wp` / `just wp-clean path=/path/to/wp`.

## Rules

- Never echo `WP_PASSWORD`; reuse via the `.env` file above.
- Use a **real form login** (this script). Do **not** inject `wp_generate_auth_cookie` cookies —
  those tokens aren't registered sessions, so REST nonces 403 and editor saves fail silently.

## Handoff rules

- Logged in and need to drive the block editor → **wordpress-gutenberg**.
- Browser primitives (snapshot refs, dialogs, iframes) → **playwright-cli**.
- Verify what the UI persisted → **wordpress-wp-cli** (`wp post meta get`).
- Editor/REST errors during a test → **wordpress-debugging**.

## WordPress skill group

Parent group: **WordPress**. Siblings: `wordpress-diagnostics` · `wordpress-debugging` ·
`wordpress-wp-cli` · `wordpress-gutenberg` · `wordpress-penetration-testing` ·
`wordpress-woocommerce-development`. Browser primitives: `playwright-cli`.
