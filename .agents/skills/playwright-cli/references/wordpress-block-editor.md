# Driving the WordPress Block Editor (Gutenberg)

Browser-automation mechanics for the WordPress block editor. For WordPress state APIs
(`wp.data` read/select/save), the click-vs-`wp.data` accuracy rule, and out-of-band
verification, see the **wordpress** skill's `references/gutenberg.md`. For an authenticated
session, use the **wordpress** skill's `references/test-login.md`.

## WP 7.0 reality

- The post editor canvas is an **iframe by default** (core 7.0). Page-level CSS/text selectors
  do **not** reach block content — target it by snapshot ref. Frame refs are prefixed `fNeN`
  (e.g. `f2e18`); pass the bare ref: `playwright-cli click f2e18`.
- Snapshot refs belong to the latest snapshot and **renumber on reload** (`f2e18` -> `f4e18`):
  snapshot -> grep -> act, every time. Wait `sleep 3` after `goto` for hydration.

## UI path — exercise a control end-to-end

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

## Reading values not in the snapshot

`playwright-cli eval` runs in the page, where `wp.data` is available — the fast, exact path
for reading/selecting/saving blocks and staged post meta. See `references/gutenberg.md` in the
wordpress skill for those snippets and when clicking is required instead.
