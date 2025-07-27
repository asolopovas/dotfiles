# Squid Installation Test Suite

Comprehensive testing framework for the Squid proxy installation script.

## Quick Start

```bash
# Run basic syntax tests (safe, no sudo required)
make test-bash

# Or run directly:
./tests/bash/squid/run_squid_tests.sh
```

## Test Options

### Default (Syntax Only)
```bash
./tests/bash/squid/run_squid_tests.sh
```
- ✅ Safe to run without sudo
- Tests script syntax and structure
- Validates configuration files
- Checks all required functions exist

### Full Functionality Test
```bash
sudo ./tests/bash/squid/run_squid_tests.sh --full
```
- ⚠️ **Requires sudo privileges**
- ⚠️ **Installs actual Squid proxy**
- Tests complete installation process
- Validates proxy functionality with curl
- Tests SSL certificates
- Verifies iptables rules
- Checks systemd service
- Performance testing

### Syntax Only
```bash
./tests/bash/squid/run_squid_tests.sh --syntax
```
- Same as default, explicit syntax testing

### Cleanup
```bash
sudo ./tests/bash/squid/run_squid_tests.sh --clean
```
- Removes Squid installation
- Cleans test artifacts
- Restores system state

## What Gets Tested

### Syntax Tests (Safe)
- ✅ Script syntax validation
- ✅ Required functions (14 functions)
- ✅ Configuration templates (5 files)
- ✅ Utility function patterns
- ✅ Error handling patterns
- ✅ Sudo requirement checks

### Full Functionality Tests (Requires Sudo)
- 🔧 **Installation Process**
  - Dependencies installation
  - Squid compilation from source
  - SSL certificate generation
  - Configuration file creation
  - Cache initialization

- 🌐 **Proxy Functionality**
  - HTTP proxy with curl
  - HTTPS proxy with curl
  - Certificate validation
  - Performance testing

- 🛡️ **Security & System Integration**
  - Transparent proxy (iptables)
  - SSL/TLS certificates
  - User permissions (proxy user)
  - Systemd service
  - Cache permissions

- 🧪 **Edge Cases**
  - Baseline connectivity
  - Service startup/shutdown
  - Configuration parsing
  - Port availability

## Test Structure

```
tests/bash/squid/
├── run_squid_tests.sh          # Main entry point
├── test_squid_functionality.sh # Full functionality tests
└── README.md                   # This file
```

## Integration with Makefile

The main project Makefile provides a simple interface:

```bash
make test-bash      # Run syntax tests
make clean-tests    # Clean all test artifacts
make help          # Show available targets
```

## Example Output

### Syntax Tests
```
=== Squid Installation Tests (Default: Syntax Only) ===

[INFO] Running safe syntax tests (use --full for complete testing)
[PASS] Script validation tests passed
[PASS] Utility function tests passed  
[PASS] All required functions found (14 functions)
[PASS] All configuration templates found (5 files)

✅ Syntax tests passed!
```

### Full Tests
```
============================================
   Squid Installation Functionality Test
============================================

[PASS] Prerequisites check passed
[PASS] Baseline connectivity working
[PASS] Squid installation completed successfully
[PASS] Squid binary working: Squid Cache: Version 7.1
[PASS] Squid configuration syntax is valid
[PASS] Squid service running, listening on ports: 3128 3129 3130
[PASS] SSL certificates are valid
[PASS] HTTP proxy functionality working
[PASS] HTTPS proxy functionality working
[PASS] Transparent proxy iptables rules configured
[PASS] Cache directory configured correctly
[PASS] Squid systemd service is enabled
[PASS] Proxy performance acceptable (1.2s)

🎉 ALL FUNCTIONALITY TESTS PASSED!
✅ Squid proxy is fully functional and ready to use
```

## Safety Features

- **Default safe mode**: Only syntax tests run without explicit --full flag
- **Sudo validation**: Checks for proper sudo usage
- **Baseline connectivity**: Verifies internet access before installation
- **Comprehensive cleanup**: --clean option restores system state
- **Timeout protection**: Tests have timeouts to prevent hanging
- **Prerequisites check**: Validates required commands exist

## Troubleshooting

### Common Issues

1. **Test hangs**: Use timeout commands, check internet connectivity
2. **Permission errors**: Ensure using sudo for --full tests
3. **Missing dependencies**: Install build-essential, curl, wget, openssl
4. **Port conflicts**: Stop existing services on ports 3128-3130

### Debug Mode

For detailed output, run tests manually:
```bash
sudo ./tests/bash/squid/test_squid_functionality.sh
```

### Log Files

Test logs are saved to `/tmp/squid-*-test-*.log` for debugging.