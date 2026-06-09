---
name: wordpress-test-login
description: "Fast sign-in to a local WordPress wp-admin to start Playwright CLI inspection or testing. Provisions a dedicated test admin with a random password stored securely, then logs the browser in. Use whenever a task needs an authenticated WordPress session via playwright-cli."
risk: medium
source: user-requirements
created: "2026-06-09"
---

# WordPress Test Login

Fast authenticated wp-admin session for playwright-cli. Local/dev sites only.
Provisions a dedicated `pi-test-admin`; never touches real users.

## Fast sign-in

```bash
bash <skill_dir>/scripts/wp-test-login.sh /path/to/wordpress
```

One command: provisions/rotates `pi-test-admin` (random WP-generated password), stores creds
chmod 600 at `${XDG_DATA_HOME:-$HOME/.local/share}/wp-test-auth/<host>.env`, opens
playwright-cli, and logs into wp-admin in the default session. Prints `Logged in -> wp-admin
ready` on success. No secrets are printed.

Then inspect/test in the same session, e.g.:

```bash
playwright-cli goto http://<host>/wp-admin/post.php?post=<ID>&action=edit
playwright-cli snapshot --filename=/tmp/edit.yml   # YAML goes to the file, not stdout
```

## Requirements

- `wp` (wp-cli): check `command -v wp`. Install: download `wp-cli.phar`, `chmod +x`,
  move to `/usr/local/bin/wp`.
- `playwright-cli` (for the browser login). The script falls back to provision-only if absent.

## Rules

- Local hosts only (`*.test`, `*.local`, localhost); the script refuses others.
- Never echo `WP_PASSWORD`. To reuse creds: `set -a; . <host>.env; set +a`.

## playwright-cli gotchas (v0.1.0)

- `--raw` is unsupported; parse normal output (`eval` prints the value after `### Result`).
- `snapshot` stdout is only a link; use `snapshot --filename=FILE` and read the YAML.
- `fill` accepts only snapshot refs (`e12`), not CSS/locators; `click` accepts CSS.
  The script discovers login-form refs from the snapshot, then fills by ref.
- `run-code` is a sandboxed VM: no `process.env`, no `require`, no dynamic `import`.
  Do not pass secrets through it.
- Do NOT inject `wp_generate_auth_cookie` cookies: tokens are not registered as sessions,
  so REST nonces 403 and Gutenberg saves fail silently. Real form login (this script)
  gives a valid session + `wp_rest` nonce.
- Leaving the editor fires a `beforeunload` dialog: `playwright-cli dialog-accept` first.

## Clean up

```bash
playwright-cli close
wp --path=<wp> user delete pi-test-admin --reassign=1 --yes
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/wp-test-auth/<host>.env"
```

## Task runner

Copy `assets/justfile` or `assets/Makefile` (`wp-login`, `wp-clean`) into a project.
