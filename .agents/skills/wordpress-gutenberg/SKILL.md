---
name: wordpress-gutenberg
description: "Operate the WordPress block editor (Gutenberg) from an automated browser: read, select, edit, and save blocks via core wp.data, and drive UI controls when real handlers must fire. Use for any block-editor inspection or test."
group: WordPress
risk: medium
---

# WordPress Gutenberg (Block Editor)

**Purpose** — Inspect and manipulate the block editor accurately and fast, using stable core
WordPress APIs (`wp.data`) for state and `playwright-cli` for real user input.

**When to use** — Reproduce/verify editor behavior, read or set block attributes, assert UI
control state, trigger a save. For wp-admin auth first, use **wordpress-test-login**; for
browser primitives, **playwright-cli**.

**Required inputs**
- An authenticated editor session (run **wordpress-test-login**) on a local/dev site.
- `playwright-cli` driving that session, with the editor open (`.../post.php?post=<ID>&action=edit`).
- `wp` for out-of-band verification (**wordpress-wp-cli**).

## WordPress 7.0 reality

- The post editor canvas is an **iframe by default** (core 7.0). Page-level CSS/text selectors
  do **not** reach block content — target it by snapshot ref (frame refs are prefixed `fNeN`,
  e.g. `f2e18`; pass the bare ref: `playwright-cli click f2e18`).
- Snapshot refs belong to the latest snapshot and **renumber on reload** (`f2e18`→`f4e18`):
  snapshot → grep → act, every time. Wait `sleep 3` after `goto` for hydration.

## Key actions

### Fast path — read / select / save via core `wp.data` (verified, no clicking)

`playwright-cli eval` runs in the page; `wp.data` is available there. Blocks nest, so walk
`innerBlocks` recursively.

```bash
# READ a block's attributes by name (recursive walk handles nested blocks)
playwright-cli eval "() => { const all=[]; const walk=bs=>bs.forEach(b=>{all.push(b);walk(b.innerBlocks)}); walk(wp.data.select('core/block-editor').getBlocks()); const b=all.find(x=>x.name==='<namespace/block>'); return JSON.stringify(b.attributes); }"

# SELECT a block (this is what populates its inspector panels)
#   ...same walk... wp.data.dispatch('core/block-editor').selectBlock(b.clientId)
#   confirm: wp.data.select('core/block-editor').getSelectedBlockClientId()

# READ post meta the editor has staged (entity record, core stable)
playwright-cli eval "() => { const s=wp.data.select('core/editor'); return JSON.stringify(wp.data.select('core').getEditedEntityRecord('postType', s.getCurrentPostType(), s.getCurrentPostId()).meta); }"

# SAVE programmatically, then poll until done
playwright-cli eval "() => { wp.data.dispatch('core/editor').savePost(); return 'saving'; }"
# poll: wp.data.select('core/editor').isSavingPost()  // true -> false when complete
```

### Accuracy rule — when to click instead of `wp.data`

`updateBlockAttributes` / `editEntityRecord` change state **without firing the block's React
control handlers**. Side effects you may be testing — validation, derived state, and **meta
that a control syncs on change** — will NOT run. **Verified:** setting `fieldValues` via
`updateBlockAttributes` left the bound post meta unchanged.

- Testing real user behavior or a control's side effects → **drive the UI** (snapshot → click).
- Reading, asserting, selecting, or saving → use `wp.data` (faster, exact).

### UI path — exercise a control end-to-end

```bash
S=/tmp/wp-snapshot.yml
playwright-cli snapshot --filename=$S
grep -niE 'heading "<block title>"' $S         # find the block's canvas ref (fNeN)
playwright-cli click f4e18                       # select block -> inspector populates
playwright-cli click 'role=tab[name="Block"]'    # open the Block inspector tab
sleep 1; playwright-cli snapshot --filename=$S
# Expand the panel if collapsed, then click controls:
#   button "Toggle panel: <name>"  ->  the control buttons
playwright-cli click e506 ; playwright-cli click e515
playwright-cli snapshot --filename=$S
grep -niE '\[pressed\]' $S                        # assert control state
```

If the Block tab shows "No block selected", re-select the block (click its canvas ref) and retry.

### Verify out-of-band (source of truth)

```bash
wp post meta get <id> <key>                       # confirm persisted value
wp post get <id> --field=post_content | head      # confirm serialized block markup
curl -sS "$(wp option get siteurl)/?p=<id>"       # confirm front-end render
```

## Handoff rules

- Need an authenticated session → **wordpress-test-login**.
- Generic browser actions, refs, dialogs → **playwright-cli**.
- Confirm/inspect persisted data → **wordpress-wp-cli**.
- Editor throws an error or save fails → **wordpress-debugging** (`SCRIPT_DEBUG`, console, REST nonce).

## WordPress skill group

Parent group: **WordPress**. Siblings: `wordpress-diagnostics` · `wordpress-debugging` ·
`wordpress-wp-cli` · `wordpress-test-login` · `wordpress-penetration-testing` ·
`wordpress-woocommerce-development`. Browser primitives: `playwright-cli`.
