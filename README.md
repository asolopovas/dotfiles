# Dotfiles

Personal dotfiles and automation for Linux desktops and servers -- shell, Neovim, xmonad, tmux, and developer tooling.

## Quick Start

```bash
git clone https://github.com/asolopovas/dotfiles.git ~/dotfiles && cd ~/dotfiles && ./init.sh
```

Remote bootstrap:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

### Feature Flags

Toggle components via environment variables (all default `true` unless noted):

```bash
NODE=false FISH=false ./init.sh        # skip Node and fish
FORCE=true ./init.sh                   # force reinstall
CARGO=true CHANGE_SHELL=true ./init.sh # opt-in features (default false)
```

Available flags: `BUN`, `DENO`, `FDFIND`, `FISH`, `FZF`, `NODE`, `NVIM`, `OHMYFISH`, `CARGO`, `CHANGE_SHELL`, `FORCE`, `UNATTENDED`.

> **Note:** `init.sh` removes existing `~/.config/fish` and `~/.config/tmux` before symlinking.

## Structure

```
.config/         App configs (alacritty, fish, nvim, tmux, polybar, rofi, xmonad, gtk)
scripts/         ~90 scripts grouped by prefix (see below)
helpers/         Small CLI wrappers (system/, tools/, web/)
env/             Environment exports (vars, paths, theme)
completions/     Bash and fish completions
conf.d/          System config snippets (Barrier, Synaptics)
fzf/             fzf completion, keybindings, exclusions
tests/           Bats test suites
redis/           Redis config and service files
init.sh          Bootstrap installer with feature flags
globals.sh       Shared shell library (logging, OS detection, package helpers)
autostart.sh     Desktop autostart (compositor, polybar, flameshot)
Makefile         Build and test automation
```

## Scripts

~90 scripts in `scripts/`, organized by prefix:

| Prefix | Purpose | Examples |
|--------|---------|---------|
| `inst-` | Install tools/runtimes | docker, node (volta), nvim, fish, golang, php, redis |
| `cfg-`  | Configure system/tools | locale, proxy settings, default dirs, Plesk defaults |
| `ops-`  | Operations/maintenance | db backup, git sync, symlink refresh, worker management |
| `sec-`  | Security | SSH key auth, SSL cert import, fail2ban, permission fixes |
| `sys-`  | System tweaks | nvidia fixes, kernel modules, inotify limits, nouveau removal |
| `ui-`   | Desktop/WM | window snapping, polybar widgets, DPI, mouse/touchpad config |
| `wsl-`  | WSL-specific | win32yank, wslu, Windows Hello sudo |

## Make Targets

```bash
make help                  # list all targets
make install               # install git cache (sudo)
make test                  # run ui-snap-window bats tests (auto-installs deps)
make clean-tests           # remove /tmp test artifacts
```

## Cheatsheet

<details>
<summary>Terminal / Tmux</summary>

**Terminal:**
`Ctrl+X E` edit command | `Esc+B/F` word back/forward

**Tmux** (prefix: `Ctrl+A`):

| Key | Action |
|-----|--------|
| `C` | New window |
| `,` | Rename window |
| `P` / `N` | Previous / next window |
| `W` | Select window |
| `%` | Split vertical |
| `:` | Command mode |
| `D` | Detach |
| `Alt+-` | Horizontal layout |
| `Alt+\|` | Vertical layout |

</details>

<details>
<summary>Neovim keybindings (leader: Space)</summary>

**Navigation & Buffers:**

| Key | Action |
|-----|--------|
| `<leader>pv` | File explorer (`:Ex`) |
| `<leader>h` / `l` | Prev / next buffer |
| `<leader>bd` | Close buffer |
| `<leader>q` | Close all buffers |
| `<M-H>` / `<M-L>` | Prev / next tab |
| `<M-t>` / `<M-q>` | New / close tab |
| `<C-d>` / `<C-u>` | Page down/up (centered) |
| `n` / `N` | Search next/prev (centered) |

**Splits:**

| Key | Action |
|-----|--------|
| `<leader>vv` / `vh` | Vertical / horizontal split |
| `<M-h/j/k/l>` | Move between splits |
| `<C-M-h/j/k/l>` | Resize splits |

**Editing:**

| Key | Action |
|-----|--------|
| `<leader>f` | Format file |
| `<leader><space>` | Clear search highlight |
| `<M-J>` / `<M-K>` | Indent left / right |
| `<F5>` | Toggle hidden chars |
| `J` (normal) | Join lines, keep cursor |
| `J` / `K` (visual) | Move selection down / up |
| `<leader>p` (visual) | Paste without yanking |
| `jk` (insert) | Exit insert mode |
| `w!!` (cmdline) | Sudo write |

**Telescope:**

| Key | Action |
|-----|--------|
| `<C-p>` | Smart file finder |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fh` | Help tags |
| `<leader>fb` | File browser |
| `<leader>fd` / `fs` | Document / workspace symbols |

**Quick Edit:**

| Key | File |
|-----|------|
| `<leader>ev` | `init.lua` |
| `<leader>er` | `remap.lua` |
| `<leader>es` | `set.lua` |
| `<leader>ef` | `config.fish` |
| `<leader>ea` | `.aliasrc` |
| `<leader>sv` | Source `MYVIMRC` |

**Other:** ``<M-`>`` toggle NvimTree | `<M-S-q>` force quit

</details>

<details>
<summary>Surround.vim</summary>

| Old Text | Command | New Text |
|----------|---------|----------|
| `surr*ound_words` | `ysiw)` | `(surround_words)` |
| `*make strings` | `ys$"` | `"make strings"` |
| `[delete ar*ound me!]` | `ds]` | `delete around me!` |
| `remove <b>HTML t*ags</b>` | `dst` | `remove HTML tags` |
| `'change quot*es'` | `cs'"` | `"change quotes"` |
| `<b>or tag* types</b>` | `csth1<CR>` | `<h1>or tag types</h1>` |
| `delete(functi*on calls)` | `dsf` | `function calls` |

</details>
