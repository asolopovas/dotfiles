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

## Notes
- Installation process takes time due to building squid from source (ONE TIME ONLY)
- All proxy configurations include fallback logic when squid is not running
- System designed to work with or without proxy active
- Build preservation saves significant time on repeated installs