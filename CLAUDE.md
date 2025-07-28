# Dotfiles Project

## Project Structure
```
dotfiles/
├── completions/                    # Shell completions
│   ├── bash/                      # Bash completion scripts
│   │   ├── add-fstab.sh           # File system table additions
│   │   └── clean-data             # Data cleanup completion
│   └── fish/                      # Fish shell completions
│       ├── add-fstab.fish         # Fish fstab completion
│       ├── docker.fish            # Docker commands completion
│       └── nvm.fish               # Node version manager completion
├── config/                         # Application configurations
│   ├── alacritty/                 # Terminal emulator config
│   │   ├── alacritty.toml         # Modern TOML config
│   │   └── alacritty.yml          # Legacy YAML config
│   ├── claude/                    # Claude AI configuration
│   │   ├── agents/                # Dual-agent definitions
│   │   ├── commands/              # Custom slash commands
│   │   └── hooks/                 # Git/bash command validators
│   ├── fish/                      # Fish shell configuration
│   │   ├── functions/             # Custom fish functions
│   │   ├── conf.d/                # Fish config directory
│   │   └── config.fish            # Main fish config
│   ├── nvim/                      # Neovim configuration
│   │   ├── lua/                   # Lua configuration scripts
│   │   ├── colors/                # Color schemes
│   │   └── init.lua               # Main nvim config
│   ├── polybar/                   # Status bar configuration
│   │   ├── themes/                # Visual themes
│   │   ├── launch.sh              # Startup script
│   │   └── modules.ini            # Bar modules config
│   ├── squid/                     # Proxy server templates
│   │   ├── squid.conf.template    # Main proxy config
│   │   ├── ca.conf.template       # Certificate authority
│   │   └── server.conf.template   # Server configuration
│   └── xmonad/                    # Window manager config
│       ├── xmonad.hs              # Haskell configuration
│       └── stack.yaml             # Build configuration
├── env/                           # Environment configuration
│   ├── env-vars.sh                # Global environment variables
│   ├── theme.sh                   # UI theme settings
│   └── xmonad-vars.sh             # Window manager variables
├── helpers/                       # Utility scripts
│   ├── system/                    # System administration
│   │   ├── add-fstab              # File system management
│   │   ├── mount-linux            # Linux mount utilities
│   │   └── ubuntu-mainline-kernel.sh  # Kernel updates
│   ├── tools/                     # Development tools
│   │   ├── dmenu-pass             # Password manager menu
│   │   ├── gw                     # Git workflow helper
│   │   └── nvm-container          # Node version in container
│   └── web/                       # Web development
│       ├── devsetup               # Development environment
│       ├── hosts                  # Host file management
│       └── webconf-build          # Web config builder
├── scripts/                       # Installation & utility scripts
│   ├── install-squid.sh           # Squid proxy installation
│   ├── install-docker-registry-cache.sh  # Docker cache setup
│   ├── install-git-cache.sh       # Git caching proxy
│   ├── terminal-toggle            # Terminal window manager
│   └── test-proxy/                # Proxy testing utilities
│       ├── index.ts               # TypeScript test runner
│       └── package.json           # Node dependencies
├── tests/                         # Test suites
│   ├── bash/                      # Bash script tests
│   │   └── squid/                 # Squid-specific tests
│   ├── test-terminal-toggle.bats  # Terminal focus bug test
│   └── test-snap-window.bats      # Window snapping tests
├── tmp/                           # Temporary experiments
│   ├── gitcache/                  # Git cache experiments
│   │   ├── src/                   # Source code
│   │   └── test/                  # Test experiments
│   └── git-mirror/                # Git mirroring tests
├── Makefile                       # Build automation
├── CLAUDE.md                      # Project documentation
└── README.md                      # Project overview
```

## Commands
- `make install` - Install all (squid + docker cache + git cache)
- `make install-squid` / `make test-squid` / `make uninstall-squid`
- `make install-docker-registry-cache` / `make test-docker-registry-cache` / `make uninstall-docker-registry-cache`
- `make install-git-cache` / `make test-git-cache` / `make uninstall-git-cache`
- `make test-bash` - Run BAT tests

## Key Rules
- **Proxy testing**: Docker pulls only, never curl. Check squid logs for TCP_HIT
- **Build preservation**: Never delete `/usr/local/squid/` (10+ min build)
- **Terminal testing**: Use dual-agent BAT tests only, never manual execution
- **Commands**: Run individually, never combine with && or pipes
- **Experiments**: Use `tmp/` directory, clean up after
- **Never use timeouts**: timeouts are unreliable and bad practice reserve to alternatives


## Cache Locations
- Docker: `localhost:5000/library/image:tag` → `/mnt/d/.cache/docker-registry`
- Git: Normal clone commands → `/mnt/d/.cache/git`
- Squid logs: `/usr/local/squid/var/logs/access.log`

## Terminal Toggle Bug
**Issue**: After Super+Shift+Enter opens second terminal, Super+Enter toggles first terminal instead of second (focus tracking)
**Test**: `bats tests/test-terminal-toggle.bats` - reproduces bug, ready for fix
