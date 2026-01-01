# Dotfiles

A collection of my personal configurations and scripts for terminal tools, Tmux, Neovim, and more.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

## Terminal

|Shortcut|Description|
|---|---|
| `Ctrl + X E` | Edit command line |
| `Esc + B`    | Move one word back |
| `Esc + F`    | Move one word forward |

## Tmux

|Shortcut|Description|
|---|---|
| `Ctrl + A C`      | Create new window |
| `Ctrl + A ,`      | Rename window |
| `Ctrl + A P`      | Previous window |
| `Ctrl + A N`      | Next window |
| `Ctrl + A W`      | Select windows |
| `Ctrl + A %`      | Split vertically |
| `Ctrl + A :`      | Named commands |
| `Ctrl + A D`      | Detach from session |
| `Ctrl + A Alt+-`  | Horizontal Layout |
| `Ctrl + A Alt+\|` | Vertical Layout |

## Neovim

|Shortcut|Action|
|---|---|
| `Ctrl + V`       | Visual block mode |
| `Shift + >`      | Indent line |
| `Shift + N >`    | Indent line N steps |
| `F7`             | Reindent file |
| `Shift + { \| }` | Select lines between curly brackets |
| `vib \| cib`     | Select visual or change selection inside block |
| `ci} \| ci{`     | Select visual or change selection inside block |
| `Shift + { \| }` | Select lines between curly brackets |
| `m{letter}`      | Mark line (use capital letter for global marks) |
| `'{letter}`      | Jump to marked line |

<!-- Telescope -->
| Shortcut         | Action                                      |
|------------------|---------------------------------------------|
| `<C-p>`          | Smart file finder (`smart_find_files`) |
| `<leader>ff`     | Find files using Telescope's `find_files` |
| `<leader>fh`     | Search help tags |
| `<leader>fb`     | Open Telescope file browser |
| `<leader>fd`     | List document symbols from LSP |
| `<leader>fs`     | List workspace symbols from LSP |
| `<leader>fg`     | Live grep with arguments (`live_grep_args`) |

## Surround.vim plugin memo

| Old Text                     | Command       | New Text |
|------------------------------|--------------|----------|
| `surr*ound_words`            | `ysiw)`      | `(surround_words)` |
| `*make strings`              | `ys$"`       | `"make strings"` |
| `[delete ar*ound me!]`       | `ds]`        | `delete around me!` |
| `remove <b>HTML t*ags</b>`   | `dst`        | `remove HTML tags` |
| `'change quot*es'`           | `cs'"`       | `"change quotes"` |
| `<b>or tag* types</b>`       | `csth1<CR>`  | `<h1>or tag types</h1>` |
| `delete(functi*on calls)`    | `dsf`        | `function calls` |

## Project Structure
```
dotfiles/
├── completions/                    # Shell completions
├── config/                         # Application configurations
├── env/                            # Environment configuration
├── helpers/                        # Utility scripts
├── scripts/                        # Installation & utility scripts
├── tests/                          # Test suites
├── tmp/                            # Temporary experiments
├── Makefile                        # Build automation
└── README.md                       # Project overview
```

## Commands
- `make install` - Install all (squid + docker cache + git cache)
- `make install-squid` / `make test-squid` / `make uninstall-squid`
- `make install-docker-registry-cache` / `make test-docker-registry-cache` / `make uninstall-docker-registry-cache`
- `make install-git-cache` / `make test-git-cache` / `make uninstall-git-cache`
- `make test-bash` - Run Bats tests

## Key Rules
- **TDD ONLY**: NEVER fix code directly. Always fix through tests using TDD. This is the highest priority rule above all others.
- **Proxy testing**: Docker pulls only, never curl. Check squid logs for TCP_HIT.
- **Build preservation**: Never delete `/usr/local/squid/` (10+ min build).
- **Terminal testing**: Use dual-agent Bats tests only, never manual execution.
- **Commands**: Run individually, never combine with `&&` or pipes.
- **Experiments**: Use `tmp/` directory, clean up after.
- **Never use timeouts**: Timeouts are unreliable and bad practice; prefer alternatives.
- **Difficult tests**: Use real hotkey emulation with `xdotool key`, log states after each action with descriptive labels for later reflection.
- **Hotkey analysis**: Use `press_and_log()` to save state logs to `~/dotfiles/tmp/hotkey-*.log`.
- **Thorough testing**: Test focus switching, Alt+Tab behavior, state file updates, and terminal response to focus changes with complete logging.

## Cache Locations
- Docker: `localhost:5000/library/image:tag` → `/mnt/d/.cache/docker-registry`
- Git: Normal clone commands → `/mnt/d/.cache/git`
- Squid logs: `/usr/local/squid/var/logs/access.log`

## Terminal Toggle Bug
**Issue**: After Super+Shift+Enter opens second terminal, Super+Enter toggles first terminal instead of second (focus tracking).  
**Test**: `bats tests/test-terminal-toggle.bats` reproduces the bug and is ready for fix.
