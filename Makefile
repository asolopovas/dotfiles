# Dotfiles Project Makefile
.PHONY: help test test-ui-snap-window clean-tests install-test-deps install install-git-cache test-git-cache uninstall-git-cache kill-alacritty

# Common variables
CLEAR_PROXY_ENV = env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY
SUDO_NO_PROXY = sudo -E $(CLEAR_PROXY_ENV)

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Main Installation:"
	@echo "  install             Install everything (Git cache)"
	@echo ""
	@echo "Testing:"
	@echo "  test                Run all project tests"
	@echo "  test-ui-snap-window    Run ui-snap-window functionality tests"
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
test: test-ui-snap-window
	@echo "✅ All project tests completed successfully!"

test-ui-snap-window: install-test-deps
	@echo "Running ui-snap-window functionality tests..."
	@chmod +x ./tests/run-snap-tests.sh
	@./tests/run-snap-tests.sh

# Maintenance targets
clean-tests:
	@echo "Cleaning test artifacts..."
	@rm -f /tmp/*-functions.sh
	@rm -f /tmp/mock-gum /tmp/gum
	@rm -rf /tmp/test-bin
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
			echo "Warning: bats not found, ui-snap-window tests may fail"; \
		fi \
	fi
	@chmod +x tests/bash/*.sh
	@echo "Dependencies ready"

# Main installation target
install: install-git-cache
	@echo "Complete installation finished!"
	@echo "Git cache is now configured."

# Git Cache targets
install-git-cache:
	@echo "Installing Git caching container..."
	@$(SUDO_NO_PROXY) ./scripts/inst-git-cache.sh install

test-git-cache:
	@echo "Testing Git cache configuration..."
	@sudo ./scripts/inst-git-cache.sh test

uninstall-git-cache:
	@echo "Removing Git cache container and configuration..."
	@sudo ./scripts/inst-git-cache.sh uninstall

# Utility targets
kill-alacritty:
	@echo "Killing all Alacritty processes..."
	@pkill -9 alacritty 2>/dev/null || true
	@sleep 1
	@echo "Alacritty processes killed. Remaining count: $$(wmctrl -l | grep 'Alacritty' | wc -l)"
