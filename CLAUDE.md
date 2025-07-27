# Claude Instructions for dotfiles Project

## Important Commands

### Squid Proxy Management
- **NEVER run**: `sudo /home/andrius/dotfiles/scripts/install-squid.sh` directly
- **Always use**: `make install-squid`, `make test-squid`, `make uninstall-squid`
- These Makefile targets handle proper environment and error handling

## Testing Commands
- `make test-bash` - Run bash script tests
- `make install-squid` - Install squid proxy and configure dev tools
- `make test-squid` - Test complete squid setup
- `make uninstall-squid` - Clean removal of squid

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
- SSL certificate verification may need additional configuration for some tools