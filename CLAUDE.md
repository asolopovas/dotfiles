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

## Notes
- Installation process takes time due to building squid from source
- All proxy configurations include fallback logic when squid is not running
- System designed to work with or without proxy active