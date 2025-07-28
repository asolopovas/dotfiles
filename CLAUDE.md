# Claude Instructions for dotfiles Project

## Important Commands

### Main Installation
- `make install` - Install everything (Squid proxy + Docker registry cache)

### Squid Proxy Management
- **NEVER run**: `sudo /home/andrius/dotfiles/scripts/install-squid.sh` directly
- **Always use**: `make install-squid`, `make test-squid`, `make uninstall-squid`
- These Makefile targets handle proper environment and error handling

### Docker Registry Cache Management
- **NEVER run**: `sudo /home/andrius/dotfiles/scripts/install-docker-registry-cache.sh` directly
- **Always use**: `make install-docker-registry-cache`, `make test-docker-registry-cache`, `make uninstall-docker-registry-cache`
- Docker configuration is now separate from Squid installation

### Git Cache Management
- **NEVER run**: `sudo /home/andrius/dotfiles/scripts/install-git-cache.sh` directly
- **Always use**: `make install-git-cache`, `make test-git-cache`, `make uninstall-git-cache`
- Container-based git-caching-proxy for 10-100x faster Git clones
- Git configuration is separate from Squid proxy

## Testing Commands
- `make test-bash` - Run bash script tests
- `make install-squid` - Install squid proxy and configure dev tools (tool-specific, not system-wide)
- `make test-squid` - Test complete squid setup
- `make uninstall-squid` - Clean removal of squid
- `make install-docker-registry-cache` - Install Docker proxy config and registry cache
- `make test-docker-registry-cache` - Test Docker configuration and registry cache
- `make uninstall-docker-registry-cache` - Remove Docker proxy config and registry cache
- `make install-git-cache` - Install Git caching container (10-100x faster clones)
- `make test-git-cache` - Test Git cache configuration  
- `make uninstall-git-cache` - Remove Git cache container and configuration

## Proxy Configuration
- **NO SYSTEM-WIDE PROXY**: The proxy is configured per-tool only, not globally
- **Tool-specific configuration**: Each dev tool (git, npm, pip, etc.) is individually configured
- **No interference with other apps**: Claude Code and other applications won't be affected
- **Fallback support**: Tools work normally when squid is not running

## CRITICAL BUILD PRESERVATION RULES
- **NEVER DELETE SQUID BUILD**: Once Squid is built at `/usr/local/squid/`, it must NEVER be removed
- The build should be reused forever, no matter how many install/uninstall cycles happen
- `make uninstall-squid` removes system configurations but preserves the built binary
- Only `--clean` option should remove the build (but this should rarely be used)
- Build takes 10+ minutes and should only happen once

## Testing and Verification Requirements
- **NEVER USE CURL FOR TESTING**: Only test against Docker - this is the #1 priority and strict rule
- **DOCKER IS THE ONLY TEST TOOL**: All proxy testing must be done with `docker pull` commands
- **ALWAYS UPDATE INSTALL SCRIPT**: Any fixes must be applied to install script templates and tested from uninstall to install
- **COMPLETE E2E VERIFICATION**: Always test full uninstall -> install -> Docker pull cycle to confirm everything works
- **ALWAYS confirm functionality through logs**: Check `/usr/local/squid/var/logs/access.log` for cache hits/misses
- **CACHE VERIFICATION IS MANDATORY**: Always check squid logs for `TCP_HIT`, `TCP_REFRESH_UNMODIFIED`, or `TCP_REFRESH_MODIFIED` entries - if no cache hits are seen, the solution is NOT working and must be fixed with a new approach
- **LOG ANALYSIS REQUIRED**: Look for `TCP_MISS` followed by `TCP_REFRESH_UNMODIFIED` on repeat requests to confirm caching is working
- **NO CONNECT TUNNELS FOR CACHING**: If logs show only `NONE_NONE/200 CONNECT` entries without cache hits, SSL bump/caching is failing and needs different solution
- **ALWAYS verify E2E performance**: Test actual downloads/pulls to confirm caching works  
- **ALWAYS check SSL certificates**: Ensure all tools trust Squid CA certificates where necessary
- **ALWAYS test real scenarios**: Use actual package managers, Docker pulls, git operations to verify
- **ALWAYS verify permissions**: SSL certificates must have proper permissions and be in correct locations

## Notes
- Installation process takes time due to building squid from source (ONE TIME ONLY)
- All proxy configurations include fallback logic when squid is not running
- System designed to work with or without proxy active
- Build preservation saves significant time on repeated installs
- Docker proxy works through CONNECT tunnels (visible in logs as `CONNECT registry-1.docker.io:443`)
- **Docker Registry Cache**: Use `localhost:5000/library/image:tag` for 10-20x faster pulls (cached in `/mnt/d/.cache/docker-registry`)
- **Docker Configuration Separation**: Docker configuration is now separate from Squid - use `make install-docker-registry-cache` independently
- **Git Cache**: Automatic caching for GitHub repositories - use normal `git clone https://github.com/user/repo.git` commands (cached in `/mnt/d/.cache/git`)
- **Git Configuration Separation**: Git caching is now separate from Squid - use `make install-git-cache` independently
- SSL certificate verification may need additional configuration for some tools
- **ALWAYS RUN BASH COMMANDS INDIVIDUALLY**: Never combine commands with && or pipes - run each command separately
- **NEVER USE TIMEOUT COMMANDS**: timeout is unreliable - use proper error handling and process management instead
- **Use /home/andrius/dotfiles/tmp/ for experiments**: This directory is gitignored and safe for testing
- **Clean up tmp/ directory after experiments**: Remove test files to keep the repository clean

## Error Handling Requirements
- **ALWAYS ADDRESS EVERY ERROR**: When encountering any error during testing or execution, it must be fixed before proceeding
- **TOOL-SPECIFIC ERROR HANDLING**: Different package managers have different command syntax - check if config exists before removing:
  - NPM: Use `npm config delete` (works even if config doesn't exist)
  - Yarn: Use `yarn config get` to check existence before `yarn config unset` to avoid "Invalid configuration key" errors
  - Go: Use `go env -u` (gracefully handles non-existent variables)
- **VERIFY ERROR FIXES**: After fixing errors, always test the fix to ensure it works properly
- **DOCUMENT ERROR PATTERNS**: Note common error patterns and their solutions for future reference