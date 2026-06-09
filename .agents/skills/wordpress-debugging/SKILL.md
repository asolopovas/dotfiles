---
name: wordpress-debugging
description: "Reproduce and root-cause WordPress errors — white screens, fatals, REST/AJAX failures, slow queries — using WP_DEBUG, debug.log, and plugin/theme bisection. Use after diagnostics has localized a fault."
group: WordPress
risk: medium
---

# WordPress Debugging

**Purpose** — Turn "something is broken" into a named root cause: the file, plugin/theme,
hook, or query at fault, with a reproduction and a log line.

**When to use** — A specific error or fatal needs root-causing (white screen, HTTP 500,
"critical error", REST 4xx/5xx, AJAX failure, slow page). For "is it healthy?" triage first,
use **wordpress-diagnostics**.

**Required inputs**
- WP root path / `--path`, shell access; ability to edit `wp-config.php` (or use `wp config set`).
- A reproduction trigger (URL, admin action, or WP-CLI command).

## Key actions

```bash
WP=/path/to/wp
# 1. Turn on logging WITHOUT leaking errors to visitors (logs to wp-content/debug.log).
wp --path=$WP config set WP_DEBUG true --raw --type=constant
wp --path=$WP config set WP_DEBUG_LOG true --raw --type=constant
wp --path=$WP config set WP_DEBUG_DISPLAY false --raw --type=constant
wp --path=$WP config set SCRIPT_DEBUG true --raw --type=constant   # unminified core JS/CSS (editor bugs)

# 2. Reproduce, then watch the log.
: > "$WP/wp-content/debug.log"            # truncate first for a clean capture
# ...trigger the bug (load URL / run action)...
tail -n 50 "$WP/wp-content/debug.log"

# 3. WP-CLI surfaces PHP fatals that the browser hides as a generic "critical error":
wp --path=$WP eval 'echo "ok".PHP_EOL;'   # bootstraps WP; a fatal prints the stack here

# 4. Bisect plugin/theme conflict (deactivate all, re-enable until it breaks).
wp --path=$WP plugin deactivate --all
wp --path=$WP theme activate twentytwentyfive   # known-good core theme
# re-test; then re-enable one at a time:
wp --path=$WP plugin activate <slug>            # repeat, re-testing each

# 5. REST / AJAX failures. List live namespaces, then hit the route (WP 7.0 core adds
#    wp-abilities/v1, wp-sync/v1, wp-site-health/v1 — verify the namespace, don't guess):
curl -sS "$(wp --path=$WP option get siteurl)/wp-json/" | python3 -c 'import sys,json;print(*json.load(sys.stdin)["namespaces"],sep="\n")'
wp --path=$WP eval 'echo count(wp_get_abilities())." abilities registered".PHP_EOL;'   # 7.0 Abilities API

# 6. Slow page / query debugging (no mysql binary needed):
wp --path=$WP eval 'define("SAVEQUERIES",true); /* then run a query path and inspect $wpdb->queries */'
wp --path=$WP package install wp-cli/profile-command && wp --path=$WP profile hook --all --spotlight
```

## Common causes → fix

| Log / symptom | Root cause | Fix |
|---------------|-----------|-----|
| `PHP Fatal: ... in plugins/<x>` | plugin fatal | update/replace/deactivate `<x>` |
| `Allowed memory size exhausted` | memory limit | raise `WP_MEMORY_LIMIT`; find leak via profile |
| `Call to undefined function` after update | PHP < 7.4 or missing ext | meet WP 7.0 floor (PHP 7.4+, see **wordpress-diagnostics**) |
| White screen, empty log | `WP_DEBUG_DISPLAY` off + fatal | run step 3 (`wp eval`) to see the stack |
| REST 401/403 on editor save | bad/expired nonce or auth | use a real session — **wordpress-test-login** |
| Editor blank / block error | minified asset or block JS | `SCRIPT_DEBUG true`; inspect via **wordpress-gutenberg** |

## Handoff rules

- Always restore production config when done:
  `wp config set WP_DEBUG false --raw --type=constant` (and `WP_DEBUG_LOG`, `SCRIPT_DEBUG`).
- Need data/state changes to test a fix → **wordpress-wp-cli**.
- Bug only reproduces through the UI/editor → **wordpress-test-login** + **wordpress-gutenberg**.
- Integrity failure / injected code in the log → **wordpress-penetration-testing**.

## WordPress skill group

Parent group: **WordPress**. Siblings: `wordpress-diagnostics` · `wordpress-wp-cli` ·
`wordpress-test-login` · `wordpress-gutenberg` · `wordpress-penetration-testing` ·
`wordpress-woocommerce-development`.
