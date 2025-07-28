# Dotfiles Project Makefile
.PHONY: help test test-bash test-bash-verbose test-snap-window clean-tests install-test-deps install install-squid test-squid uninstall-squid install-docker-registry-cache test-docker-registry-cache uninstall-docker-registry-cache install-git-cache test-git-cache uninstall-git-cache

# Common variables
CLEAR_PROXY_ENV = env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY
SUDO_NO_PROXY = sudo -E $(CLEAR_PROXY_ENV)

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Main Installation:"
	@echo "  install             Install everything (Squid proxy + Docker registry cache + Git cache)"
	@echo ""
	@echo "Testing:"
	@echo "  test                Run all project tests"
	@echo "  test-bash           Run all bash script tests"
	@echo "  test-bash-verbose   Run E2E tests with detailed output"
	@echo "  test-snap-window    Run snap-window functionality tests"
	@echo ""
	@echo "Squid Proxy:"
	@echo "  install-squid       Install and configure Squid proxy (auto-builds if needed)"
	@echo "  test-squid          Test complete Squid proxy setup and dev environment caching"
	@echo "  uninstall-squid     Remove Squid installation and all proxy configs (keeps build for reuse)"
	@echo ""
	@echo "Docker Registry Cache:"
	@echo "  install-docker-registry-cache   Install Docker proxy config and registry cache"
	@echo "  test-docker-registry-cache      Test Docker configuration and registry cache"
	@echo "  uninstall-docker-registry-cache Remove Docker proxy config and registry cache"
	@echo ""
	@echo "Git Cache:"
	@echo "  install-git-cache               Install Git caching container (10-100x faster clones)"
	@echo "  test-git-cache                  Test Git cache configuration"
	@echo "  uninstall-git-cache             Remove Git cache container and configuration"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean-tests         Clean up test artifacts"
	@echo "  install-test-deps   Install testing dependencies"
	@echo ""
	@echo "Usage: make <target>"

# Test targets
test: test-bash test-snap-window
	@echo "✅ All project tests completed successfully!"

test-bash: install-test-deps
	@echo "Running bash script tests..."
	@chmod +x ./tests/bash/squid/run_squid_tests.sh
	@./tests/bash/squid/run_squid_tests.sh

test-snap-window: install-test-deps
	@echo "Running snap-window functionality tests..."
	@chmod +x ./tests/run-snap-tests.sh
	@./tests/run-snap-tests.sh

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
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "Installing bats testing framework..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			$(SUDO_NO_PROXY) apt-get update -qq && sudo apt-get install -y bats; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install bats-core; \
		else \
			echo "Warning: bats not found, snap-window tests may fail"; \
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

# Main installation target
install: install-squid install-docker-registry-cache install-git-cache
	@echo "Complete installation finished!"
	@echo "Squid proxy, Docker registry cache, and Git cache are now configured."

# Docker Registry Cache targets
install-docker-registry-cache:
	@echo "Installing Docker proxy configuration and registry cache..."
	@$(SUDO_NO_PROXY) ./scripts/install-docker-registry-cache.sh install

test-docker-registry-cache:
	@echo "Testing Docker configuration and registry cache..."
	@sudo ./scripts/install-docker-registry-cache.sh test

uninstall-docker-registry-cache:
	@echo "Removing Docker proxy configuration and registry cache..."
	@sudo ./scripts/install-docker-registry-cache.sh uninstall

# Git Cache targets
install-git-cache:
	@echo "Installing Git caching container..."
	@$(SUDO_NO_PROXY) ./scripts/install-git-cache.sh install

test-git-cache:
	@echo "Testing Git cache configuration..."
	@sudo ./scripts/install-git-cache.sh test

uninstall-git-cache:
	@echo "Removing Git cache container and configuration..."
	@sudo ./scripts/install-git-cache.sh uninstall
