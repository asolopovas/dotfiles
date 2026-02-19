# Dotfiles Project Makefile
.PHONY: help test test-globals test-scripts test-init test-bootstrap test-init-shell test-init-clean test-init-rebuild test-ui-snap-window clean-tests install-test-deps install install-git-cache test-git-cache uninstall-git-cache kill-alacritty

# Common variables
CLEAR_PROXY_ENV = env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY
SUDO_NO_PROXY = sudo -E $(CLEAR_PROXY_ENV)

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Main Installation:"
	@echo "  install               Install everything (Git cache)"
	@echo ""
	@echo "Testing (local, fast — core script tests):"
	@echo "  test                  Run all local bats tests (~2-5s)"
	@echo "  test-globals          Run globals.sh unit tests"
	@echo "  test-scripts          Run script unit tests"
	@echo ""
	@echo "Testing (Docker — full integration):"
	@echo "  test-init             Run Docker-based init.sh integration tests"
	@echo "  test-bootstrap        Run init.sh bootstrap and save snapshot (~5min)"
	@echo "  test-init-shell       Debug shell inside bootstrapped container"
	@echo "  test-init-clean       Remove test images and cache"
	@echo "  test-init-rebuild     Force full rebuild then run all tests"
	@echo ""
	@echo "Testing (local, requires X11):"
	@echo "  test-ui-snap-window   Run ui-snap-window functionality tests"
	@echo ""
	@echo "Git Cache:"
	@echo "  install-git-cache     Install Git caching container"
	@echo "  test-git-cache        Test Git cache configuration"
	@echo "  uninstall-git-cache   Remove Git cache container"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean-tests           Clean up test artifacts"
	@echo "  install-test-deps     Install local testing dependencies"

# ---------- Local fast test targets ----------

test: install-test-deps
	@./tests/run-tests.sh

test-globals: install-test-deps
	@./tests/run-tests.sh globals

test-scripts: install-test-deps
	@./tests/run-tests.sh scripts

# ---------- Docker integration test targets ----------

test-init:
	@./tests/run-init-tests.sh

test-bootstrap:
	@./tests/run-init-tests.sh bootstrap

test-init-shell:
	@./tests/run-init-tests.sh shell

test-init-clean:
	@./tests/run-init-tests.sh clean

test-init-rebuild:
	@./tests/run-init-tests.sh rebuild

# ---------- Local UI test targets ----------

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
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "Installing bats..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			$(SUDO_NO_PROXY) apt-get update -qq && sudo apt-get install -y bats; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install bats-core; \
		fi \
	fi

# Main installation target
install: install-git-cache
	@echo "Complete installation finished!"

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
