---
name: wordpress-wp-cli
description: "WP-CLI workflows and quick reference for WordPress diagnostics, troubleshooting, and common admin/data operations from the shell. Use whenever a task needs scripted WordPress changes or inspection without the browser."
group: WordPress
risk: medium
---

# WP-CLI Workflows

**Purpose** — Drive WordPress from the shell: inspect state, run admin/data operations, and
provide the source-of-truth quick reference the other WordPress skills hand off to.

**When to use** — Any scripted or repeatable WordPress task: read/write options, posts, meta,
users; manage plugins/themes; search-replace; flush caches; run cron; export/import. Prefer
this over UI clicking for accuracy and speed.

**Required inputs**
- Shell access to the host (or container) running WordPress.
- WordPress path: run from the WP root, or pass `--path=/path/to/wp` to every command.
- `wp` on `PATH` (`command -v wp`). Install: download `wp-cli.phar`, `chmod +x`, move to `/usr/local/bin/wp`.

**WordPress 7.0 "Armstrong" (released 20 May 2026) context** — floors raised: **PHP 7.4 minimum**
(8.3+ recommended), **MySQL 8.0 minimum**. Core ships the AI Client, Connectors API, and the
**Abilities API** (`wp_register_ability`, REST `/wp-json/wp-abilities/v1/`) — WordPress is now natively
agentic. The post editor is **iframed** by default (see `wordpress-gutenberg`).

**Two ways to run SQL — pick by environment:**
- `wp db query "..."` needs the `mysql`/`mariadb` client binary on PATH (many app containers lack it).
- `wp eval "global \$wpdb; ..."` runs through PHP/PDO and **always works** — prefer it for portability.
- Table prefix is **not** always `wp_` (check `wp config get table_prefix`); in `wp eval` use
  `$wpdb->options` / `$wpdb->posts` so the prefix is resolved for you.

## Key actions — quick reference

Run `wp --path=<wp> ...` (path omitted below for brevity).

```bash
# Core / health
wp core version --extra                 # version + update channel
wp core check-update                    # pending core updates
wp core verify-checksums                # detect tampered core files
wp cli info                             # PHP binary, config paths

# Config / options
wp config get table_prefix
wp option get siteurl ; wp option get home
wp option update blogname "New Name"

# Plugins / themes
wp plugin list --status=active --fields=name,version,update
wp plugin deactivate <slug> ; wp plugin activate <slug>
wp theme list --fields=name,status,version
wp plugin verify-checksums --all        # tampered plugin files

# Users
wp user list --fields=ID,user_login,roles
wp user create bob bob@x.test --role=editor --user_pass="$(wp eval 'echo wp_generate_password(24,true,false);')"
wp user update <id> --user_pass=...     # reset password

# Posts / meta (source of truth for block + bound-meta state)
wp post list --post_type=product --fields=ID,post_title
wp post get <id> --field=post_content
wp post meta get <id> <key>
wp post meta update <id> <key> '["a","b"]' --format=json
wp post meta list <id> --format=json

# Search-replace (migrations) — ALWAYS dry-run first
wp search-replace 'old.test' 'new.test' --dry-run --report-changed-only
wp search-replace 'old.test' 'new.test' --precise --skip-columns=guid

# Database
wp db check ; wp db size --tables
wp db export backup.sql                 # before risky changes
# Autoload audit (portable). NOTE: WP 6.6+ changed the autoload column values from yes/no
# to on/off/auto/auto-on/auto-off — `autoload='yes'` now matches NOTHING. Match the live set:
wp eval "global \$wpdb; echo \$wpdb->get_var(\"SELECT ROUND(SUM(LENGTH(option_value))/1024,1) FROM \$wpdb->options WHERE autoload IN ('yes','on','auto','auto-on')\").' KB autoloaded'.PHP_EOL;"
wp eval "global \$wpdb; foreach(\$wpdb->get_results(\"SELECT option_name,LENGTH(option_value) b FROM \$wpdb->options WHERE autoload IN ('yes','on','auto','auto-on') ORDER BY b DESC LIMIT 10\") as \$r){echo \$r->option_name.': '.\$r->b.PHP_EOL;}"

# Cache / rewrite / cron
wp cache flush ; wp transient delete --all
wp rewrite flush --hard                 # fix 404s after permalink/structure changes
wp cron event list ; wp cron event run --due-now

# Maintenance / scaffolding
wp maintenance-mode status|activate|deactivate
wp eval 'echo home_url();'              # run arbitrary PHP in WP context
wp eval 'echo wp_get_environment_type();'   # local|development|staging|production (default production)
wp shell                                # interactive REPL

# Optional packages (not bundled) — install once if needed:
wp package install wp-cli/profile-command   # then: wp profile stage --all  (find slow hooks)
wp package install wp-cli/doctor-command    # then: wp doctor check --all    (health rules)
```

## Troubleshooting one-liners

```bash
wp plugin list --status=active --field=name | xargs -I{} sh -c 'wp plugin deactivate {} && echo "off:{}"'  # bisect a fatal
wp option get active_plugins --format=json   # if admin is down (prefix-safe, no SQL)
wp option update blog_public 0          # ensure noindex on staging
wp eval 'var_dump(get_option("template"), get_option("stylesheet"));'        # active theme sanity
```

## Handoff rules

- Error/white screen with unknown cause → **wordpress-debugging** (logs + WP_DEBUG + bisect).
- "Is the site healthy?" fast triage → **wordpress-diagnostics**.
- Need to assert UI/editor behavior → **wordpress-test-login** then **wordpress-gutenberg**.
- Destructive ops (`search-replace`, `db query` writes, bulk `post delete`): `wp db export` first; on production confirm scope with the user.

## WordPress skill group

Parent group: **WordPress**. Siblings: `wordpress-diagnostics` · `wordpress-debugging` ·
`wordpress-test-login` · `wordpress-gutenberg` · `wordpress-penetration-testing` ·
`wordpress-woocommerce-development`. Browser primitives: `playwright-cli`.
