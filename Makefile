# Dotfiles Project Makefile
.PHONY: help test-bash test-bash-verbose clean-tests install-test-deps install-squid test-squid uninstall-squid

# Common variables
CLEAR_PROXY_ENV = env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY
SUDO_NO_PROXY = sudo -E $(CLEAR_PROXY_ENV)

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Testing:"
	@echo "  test-bash           Run all bash script tests"
	@echo "  test-bash-verbose   Run E2E tests with detailed output"
	@echo ""
	@echo "Squid Proxy:"
	@echo "  install-squid       Install and configure Squid proxy (auto-builds if needed)"
	@echo "  test-squid          Test complete Squid proxy setup and dev environment caching"
	@echo "  uninstall-squid     Remove Squid installation and all proxy configs (keeps build for reuse)"
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
			$(SUDO_NO_PROXY) apt-get update -qq && sudo apt-get install -y gum; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install gum; \
		else \
			echo "Warning: gum not found, tests will use mock version"; \
		fi \
	fi
	@chmod +x tests/bash/*.sh
	@echo "Dependencies ready"

# Squid Proxy targets
install-squid:
	@if [ -x /usr/local/squid/sbin/squid ]; then \
		echo "Squid already built, configuring only..."; \
		$(SUDO_NO_PROXY) ./scripts/install-squid.sh --install-only; \
	else \
		echo "Installing Squid proxy and configuring all development tools..."; \
		$(SUDO_NO_PROXY) ./scripts/install-squid.sh; \
	fi

test-squid: install-squid
	@echo "Testing complete Squid proxy setup and dev environment caching..."
	@sudo ./scripts/install-squid.sh --test

uninstall-squid:
	@echo "Removing Squid proxy from system (preserving build)..."
	@sudo ./scripts/install-squid.sh --uninstall
