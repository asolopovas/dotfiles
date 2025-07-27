# Dotfiles Project Makefile
.PHONY: help test-bash clean-tests install-test-deps test-squid squid-uninstall

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Testing:"
	@echo "  test-bash           Run all bash script tests"
	@echo "  test-bash-verbose   Run E2E tests with detailed output"
	@echo "  test-squid          Install and test complete Squid proxy setup"
	@echo ""
	@echo "Squid Proxy:"
	@echo "  test-squid          Install and test Squid with global proxy environment"
	@echo "  squid-uninstall     Completely remove Squid and all traces from system"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean-tests         Clean up test artifacts"
	@echo "  install-test-deps   Install testing dependencies"
	@echo ""
	@echo "Usage: make <target>"

# Test targets
test-bash: install-test-deps
	@echo "Running bash script tests..."
	@chmod +x ./tests/bash/squid/run_squid_tests.sh
	@./tests/bash/squid/run_squid_tests.sh

test-bash-verbose: install-test-deps
	@echo "Running verbose E2E Squid tests..."
	@chmod +x ./tests/bash/squid/test_squid_verbose.sh
	@./tests/bash/squid/test_squid_verbose.sh

# Maintenance targets
clean-tests:
	@echo "Cleaning test artifacts..."
	@chmod +x ./tests/bash/squid/run_squid_tests.sh
	@./tests/bash/squid/run_squid_tests.sh --clean || true
	@rm -f /tmp/squid-*-test-*.log
	@rm -f /tmp/*-functions.sh
	@rm -f /tmp/mock-gum /tmp/gum
	@rm -rf /tmp/test-squid* /tmp/test-cache /tmp/test-bin
	@rm -f /tmp/*.log
	@echo "Test artifacts cleaned"

install-test-deps:
	@echo "Checking test dependencies..."
	@if ! command -v gum >/dev/null 2>&1; then \
		echo "Installing gum for better output formatting..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update -qq && sudo apt-get install -y gum; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install gum; \
		else \
			echo "Warning: gum not found, tests will use mock version"; \
		fi \
	fi
	@chmod +x tests/bash/*.sh
	@echo "Dependencies ready"

# Squid Proxy targets
test-squid:
	@echo "Installing and testing Squid proxy setup..."
	@sudo ./scripts/install-squid.sh
	@echo ""
	@echo "Testing global proxy environment..."
	@echo "Testing curl with proxy:"
	@curl -s --proxy http://localhost:3128 http://httpbin.org/get | head -3 || echo "Proxy test failed"
	@echo ""
	@echo "Checking systemd service:"
	@systemctl is-active squid && echo "✓ Squid service is running" || echo "❌ Squid service failed"
	@echo ""
	@echo "Checking proxy environment variables:"
	@grep -q "HTTP_PROXY" /etc/environment.d/99-proxy.conf 2>/dev/null && echo "✓ Global proxy environment configured" || echo "❌ Global proxy environment missing"
	@echo ""
	@echo "✓ Squid proxy setup test complete"
	@echo "Note: You may need to restart your session for global proxy to take effect"

squid-uninstall:
	@echo "Completely removing Squid proxy from system..."
	@sudo ./scripts/install-squid.sh --clean
	@echo "✓ Squid proxy completely removed from system"