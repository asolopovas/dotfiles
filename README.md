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
├── config/        # App configs (fish, tmux, nvim, polybar, squid, rofi, gtk)
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
├── askpass.sh                      # masked password prompt helper
├── ban-ips.sh                      # ban IPs from logs via fail2ban
├── check-err.sh                    # view/clear common system logs
├── conf                            # push/pull predefined git paths
├── config-gnome-terminal.sh        # apply Alacritty-like GNOME Terminal profile
├── configure-dev-tools-proxy.sh    # set proxy for git/npm/pip/curl/docker
├── cpanel-cert-import.sh           # install SSL cert/key via WHM API
├── db_backup.sh                    # export DB tables into per-table SQL
├── default-dirs.sh                 # create default dirs + symlink dotfiles
├── disable-mouse-on-touchpad.sh    # udev rule to disable touchpad on mouse
├── disable-ubuntu-shortcuts.sh     # disable GNOME dash hotkeys
├── fix-cpanel-perms.sh             # fix cPanel user ownership/permissions
├── fix-nvidia-settings.sh          # fix NVIDIA settings permissions/paths
├── fix-tearing-intel-adler.sh      # tweak i915 params to reduce tearing
├── fix-vite.sh                     # raise inotify + nofile limits
├── flip.sh                         # swap Claude credential files
├── generate-polybar-fonts.sh       # build polybar fonts from template
├── install-bash.sh                 # build/install bash from source
├── install-bfg.sh                  # install BFG repo cleaner
├── install-cinnamon-settings.sh    # apply Cinnamon desktop settings
├── install-claude.sh               # install Claude Code CLI
├── install-cog.sh                  # install Replicate cog
├── install-composer.sh             # install Composer
├── install-cryptomator.sh          # install Cryptomator
├── install-deno.sh                 # install Deno
├── install-docker-registry-cache.sh # install Docker registry cache
├── install-docker.sh               # install Docker
├── install-fastcompmgr.sh          # build/install fastcompmgr compositor
├── install-fd.sh                   # install fd
├── install-fish.sh                 # install fish shell
├── install-font.sh                 # install fonts
├── install-fzf.sh                  # install fzf
├── install-gcloud.sh               # install Google Cloud SDK
├── install-ghc.sh                  # install GHC
├── install-git-cache.sh            # install git cache container
├── install-gitcli.sh               # install GitHub CLI (gh)
├── install-golang.sh               # install Go toolchain
├── install-gum.sh                  # install gum
├── install-hubtool.sh              # install docker hub-tool
├── install-mainline.sh             # install mainline kernel tool
├── install-menu.sh                 # interactive feature menu
├── install-node.sh                 # install Node via Volta
├── install-nvim.sh                 # install Neovim + sync plugins
├── install-ohmybash.sh             # install Oh My Bash
├── install-ohmyfish.sh             # install Oh My Fish
├── install-ohmyzsh.sh              # install Oh My Zsh
├── install-php.sh                  # install PHP version packages
├── install-plesk-defaults.sh       # apply Plesk defaults
├── install-redis-service.sh        # install Redis systemd service
├── install-redis.sh                # build/install Redis from source
├── install-rye.sh                  # install Rye + Python toolchains
├── install-samba.sh                # install Samba
├── install-software.sh             # install common OS packages
├── install-squid-clean.sh          # install/clean Squid (alt flow)
├── install-squid.sh                # install/configure Squid proxy
├── install-win32yank.sh            # download/extract win32yank
├── install-windows-hello.sh        # install WSL Hello sudo (evanphilip)
├── install-wp-cli.sh               # install WP-CLI
├── install-wsl-browser.sh          # install WSL browser opener
├── install-wsl-fingerprint.sh      # install WSL Hello sudo (nullpo-head)
├── install-wslu.sh                 # install wslu
├── install-xmonad.sh               # install xmonad + deps
├── latest-kernel-ubuntu.sh         # install mainline-kernel helper
├── load-kmodule.sh                 # load kernel modules (+persist)
├── logout                          # terminate user session (GDM)
├── natural-scrolling-fix.sh        # enable libinput natural scrolling
├── pam-keyring-unlock              # unlock GNOME keyring
├── pinst                           # install/update/list PHP packages
├── polybar-vram.sh                 # print GPU VRAM usage for polybar
├── polybar-xmonad.sh               # format xmonad log for polybar
├── pull-dotfiles.sh                # hard reset + pull dotfiles for all users
├── remove-nouveau.sh               # blacklist nouveau driver
├── remove-thumb.sh                 # remove generated JPG thumbnails
├── rm-symlinks-in-current-folder.sh # remove symlinks in cwd
├── screen-laptop-main.sh           # configure LightDM display layout
├── set-dpi-by-hardware.sh          # set DPI based on ThinkPad detection
├── set-mouse-speed.sh              # set xinput mouse acceleration
├── setup-locale.sh                 # generate/apply locale
├── setup-terminal-keybindings      # configure Cinnamon terminal hotkeys
├── snap-window                     # snap windows across dual monitors
├── snap-window-dynamic             # snap windows for multi-monitor layouts
├── ssh-key-auth-cpanel.sh          # install SSH key for cPanel users
├── ssh-key-auth-plesk.sh           # install SSH key for Plesk users
├── start-workers.sh                # start Laravel queue workers
├── stop-workers.sh                 # stop Laravel queue workers
├── sync-mcp-servers.sh             # sync MCP server list
├── sync-skills.sh                  # sync Codex/Claude skills
├── terminal-toggle                 # toggle Alacritty terminal visibility
├── update_git.sh                   # update repos + run composer/pnpm builds
├── update-plesk-dotfiles.sh        # reset dotfiles for Plesk users
├── update-symlinks.sh              # refresh config symlinks
└── wsl-setup.sh                    # install win32yank for WSL
```

## Key commands
- `make help` lists available targets.
- `make install` installs Squid proxy + Docker registry cache + Git cache (sudo required).
- `make test` runs shell and snap-window tests (may install deps like `bats`/`gum`).
- `make test-squid` runs full Squid tests (sudo required).

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

|Shortcut|Action|
|---|---|
| `Ctrl + V`       | Visual block mode |
| `Shift + >`      | Indent line |
| `Shift + N >`    | Indent line N steps |
| `F7`             | Reindent file |
| `Shift + { \\| }` | Select lines between curly brackets |
| `vib \\| cib`     | Select visual or change selection inside block |
| `ci} \\| ci{`     | Select visual or change selection inside block |
| `Shift + { \\| }` | Select lines between curly brackets |
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
