# Dotfiles

Personal configurations and automation scripts for terminal tooling, editors, window managers, and developer workflows.

## Quick start
```bash
git clone https://github.com/asolopovas/dotfiles.git ~/dotfiles
cd ~/dotfiles
./init.sh
```

Remote bootstrap:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

Note: `init.sh` removes existing `~/.config/fish` and `~/.config/tmux` before symlinking.

## Project structure
```
dotfiles/
├── config/        # App configs (fish, tmux, nvim, polybar, rofi, gtk)
├── scripts/       # Installers and system utilities
├── helpers/       # Small CLI helpers (system, tools, web)
├── env/           # Environment exports
├── completions/   # Bash and fish completions
├── conf.d/        # System config snippets
├── fzf/           # fzf completion and keybind configs
├── tests/         # Bats test suites and runners
├── redis/         # Redis config/service files
├── pofiles/       # Link and helper scripts
├── init.sh        # Bootstrap installer
└── Makefile       # Automation targets
```

## Scripts map
```
scripts/
├── sec-askpass.sh                  # masked password prompt helper
├── sec-ban-ips.sh                  # ban IPs from logs via fail2ban
├── ops-check-err.sh                # view/clear common system logs
├── ops-git-sync                    # push/pull predefined git paths
├── ui-gnome-terminal-config.sh     # apply Alacritty-like GNOME Terminal profile
├── cfg-dev-tools-proxy.sh          # set proxy for git/npm/pip/curl/docker
├── sec-cpanel-cert-import.sh       # install SSL cert/key via WHM API
├── ops-db-backup.sh                # export DB tables into per-table SQL
├── cfg-default-dirs.sh             # create default dirs + symlink dotfiles
├── ui-disable-mouse-on-touchpad.sh # udev rule to disable touchpad on mouse
├── ui-disable-ubuntu-shortcuts.sh  # disable GNOME dash hotkeys
├── sec-fix-cpanel-perms.sh         # fix cPanel user ownership/permissions
├── sys-fix-nvidia-settings.sh      # fix NVIDIA settings permissions/paths
├── sys-fix-tearing-intel-adler.sh  # tweak i915 params to reduce tearing
├── sys-fix-vite.sh                 # raise inotify + nofile limits
├── ui-flip.sh                      # swap Claude credential files
├── ui-polybar-fonts.sh             # build polybar fonts from template
├── inst-bash.sh                    # build/install bash from source
├── inst-bfg.sh                     # install BFG repo cleaner
├── inst-cinnamon-settings.sh       # apply Cinnamon desktop settings
├── inst-claude.sh                  # install Claude Code CLI
├── inst-cog.sh                     # install Replicate cog
├── inst-composer.sh                # install Composer
├── inst-cryptomator.sh             # install Cryptomator
├── inst-deno.sh                    # install Deno
├── inst-docker.sh                  # install Docker
├── inst-fastcompmgr.sh             # build/install fastcompmgr compositor
├── inst-fd.sh                      # install fd
├── inst-fish.sh                    # install fish shell
├── inst-font.sh                    # install fonts
├── inst-fzf.sh                     # install fzf
├── inst-gcloud.sh                  # install Google Cloud SDK
├── inst-ghc.sh                     # install GHC
├── inst-git-cache.sh               # install git cache container
├── inst-gitcli.sh                  # install GitHub CLI (gh)
├── inst-golang.sh                  # install Go toolchain
├── inst-gum.sh                     # install gum
├── inst-hubtool.sh                 # install docker hub-tool
├── inst-mainline.sh                # install mainline kernel tool
├── cfg-plesk-defaults.sh           # apply Plesk defaults
├── inst-menu.sh                    # interactive feature menu
├── inst-node.sh                    # install Node via Volta
├── inst-nvim.sh                    # install Neovim + sync plugins
├── inst-ohmybash.sh                # install Oh My Bash
├── inst-ohmyfish.sh                # install Oh My Fish
├── inst-ohmyzsh.sh                 # install Oh My Zsh
├── inst-php.sh                     # install PHP version packages
├── inst-redis-service.sh           # install Redis systemd service
├── inst-redis.sh                   # build/install Redis from source
├── inst-rye.sh                     # install Rye + Python toolchains
├── inst-samba.sh                   # install Samba
├── inst-software.sh                # install common OS packages
├── wsl-win32yank.sh                # download/extract win32yank
├── wsl-windows-hello.sh            # install WSL Hello sudo (evanphilip)
├── inst-wp-cli.sh                  # install WP-CLI
├── browser.sh                      # install WSL browser opener
├── wsl-fingerprint.sh              # install WSL Hello sudo (nullpo-head)
├── wsl-wslu.sh                     # install wslu
├── inst-xmonad.sh                  # install xmonad + deps
├── sys-latest-kernel-ubuntu.sh     # install mainline-kernel helper
├── sys-load-kmodule.sh             # load kernel modules (+persist
├── ops-logout                      # terminate user session (GDM)
├── ui-natural-scrolling-fix.sh     # enable libinput natural scrolling
├── sec-pam-keyring-unlock          # unlock GNOME keyring
├── inst-php-pkgs                   # install/update/list PHP packages
├── ui-polybar-vram.sh              # print GPU VRAM usage for polybar
├── ui-polybar-xmonad.sh            # format xmonad log for polybar
├── ops-pull-dotfiles.sh            # hard reset + pull dotfiles for all users
├── sys-remove-nouveau.sh           # blacklist nouveau driver
├── ops-remove-thumbs.sh            # remove generated JPG thumbnails
├── ops-rm-symlinks-here.sh         # remove symlinks in cwd
├── ui-screen-laptop-main.sh        # configure LightDM display layout
├── ui-set-dpi-by-hardware.sh       # set DPI based on ThinkPad detection
├── ui-set-mouse-speed.sh           # set xinput mouse acceleration
├── cfg-locale.sh                   # generate/apply locale
├── cfg-terminal-keybindings        # configure Cinnamon terminal hotkeys
├── ui-snap-window                  # snap windows across dual monitors
├── ui-snap-window-dynamic          # snap windows for multi-monitor layouts
├── sec-ssh-key-auth-cpanel.sh      # install SSH key for cPanel users
├── sec-ssh-key-auth-plesk.sh       # install SSH key for Plesk users
├── ops-start-workers.sh            # start Laravel queue workers
├── ops-stop-workers.sh             # stop Laravel queue workers
├── ops-sync-mcp-servers.sh         # sync MCP server list
├── ops-sync-skills.sh              # sync Codex/Claude skills
├── ui-terminal-toggle              # toggle Alacritty terminal visibility
├── ops-update-git.sh               # update repos + run composer/pnpm builds
├── ops-update-plesk-dotfiles.sh    # reset dotfiles for Plesk users
├── ops-update-symlinks.sh          # refresh config symlinks
└── wsl-setup.sh                    # install win32yank for WSL
```

## Key commands
- `make help` lists available targets.
- `make install` installs Git cache (sudo required).
- `make test` runs ui-snap-window tests (may install deps like `bats`/`gum`).

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
| `Ctrl + A Alt+\\|` | Vertical Layout |

## Neovim

Leader key: `Space`

Normal mode:

|Shortcut|Action|
|---|---|
| `<leader>pv`     | Open file explorer (`:Ex`) |
| `J`              | Join lines, keep cursor |
| `n` / `N`        | Next/previous search result, centered |
| `<leader>f`      | Auto-format whole file |
| `<leader><space>` | Clear search highlighting |
| `<F5>`           | Toggle hidden characters (`list`) |
| `<M-J>` / `<M-K>` | Indent left/right |
| `j` / `k`        | Move by display lines (`gj` / `gk`) |
| `<C-d>` / `<C-u>` | Page down/up, centered |
| `<leader>q`      | Close all buffers |
| `<leader>bd`     | Close current buffer |
| `<leader>bq`     | Close current buffer, keep window |
| `<leader>to`     | Close other tabs |
| `<M-q>`          | Close tab |
| `<M-t>`          | New tab |
| `<M-H>` / `<M-L>` | Previous/next tab |
| `<leader>T`      | New empty buffer |
| `<leader>h` / `<leader>l` | Previous/next buffer |
| `<M-h>` / `<M-j>` / `<M-k>` / `<M-l>` | Move between splits |
| `<leader>vh`     | Horizontal split |
| `<leader>vv`     | Vertical split |
| `<C-M-h>` / `<C-M-j>` / `<C-M-k>` / `<C-M-l>` | Resize splits |
| `<leader>er`     | Edit `remap.lua` |
| `<leader>ev`     | Edit `init.lua` |
| `<leader>ef`     | Edit `config.fish` |
| `<leader>es`     | Edit `set.lua` |
| `<leader>ea`     | Edit `.aliasrc` |
| `<leader>sv`     | Source `MYVIMRC` |
| `<leader>fml`    | CellularAutomaton: make it rain |
| ``<M-`>``        | Toggle NvimTree |
| `<M-S-q>`        | Force quit Neovim |

Visual mode:

|Shortcut|Action|
|---|---|
| `J` / `K`        | Move selection down/up |
| `<leader>p`      | Paste without yanking |
| `<` / `>`        | Indent and keep selection |

Insert mode:

|Shortcut|Action|
|---|---|
| `jk`             | Exit insert mode |
| `<M-J>` / `<M-K>` | Indent left/right |
| `<F5>`           | Toggle hidden characters (`list`) |

Command-line mode:

|Shortcut|Action|
|---|---|
| `<S-Insert>`     | Paste from clipboard |
| `w!!`            | Write file with sudo (`SudaWrite`) |
| `<F5>`           | Toggle hidden characters (`list`) |

Terminal mode:

|Shortcut|Action|
|---|---|
| ``<M-`>``        | Toggle NvimTree |
| `<M-h>` / `<M-j>` / `<M-k>` / `<M-l>` | Move between splits |
| `<M-S-h>` / `<M-S-j>` / `<M-S-k>` / `<M-S-l>` | Resize splits |
| `<M-q>`          | Close terminal buffer |
| `<M-S-q>`        | Force quit Neovim |

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
