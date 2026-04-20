# Dotfiles Project Makefile
.PHONY: help test test-globals test-scripts test-sync-ai test-inst-opencode test-init test-bootstrap test-init-shell test-init-clean test-init-rebuild test-ui-snap-window test-lint lint lint-shell lint-shell-fix lint-fish install-lint-tools clean-tests install-test-deps install kill-alacritty

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
	@echo "  test-sync-ai          Run sync-ai.sh unit tests"
	@echo "  test-inst-opencode    Run inst-opencode.sh unit tests"
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
	@echo "Linting:"
	@echo "  lint                  Run all linters (shellcheck + shfmt + fish_indent)"
	@echo "  lint-shell            shellcheck on all *.sh"
	@echo "  lint-shell-fix        shfmt -w to auto-format *.sh (writes!)"
	@echo "  lint-fish             fish_indent --check on fish files"
	@echo "  test-lint             Run lint suite via bats (skips missing tools)"
	@echo "  install-lint-tools    Install shellcheck + shfmt"
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

test-sync-ai: install-test-deps
	@./tests/run-tests.sh sync-ai

test-inst-opencode: install-test-deps
	@./tests/run-tests.sh inst-opencode

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

# ---------- Lint targets ----------

# Bash files: everything with .sh + bash shebang scripts in scripts/ and helpers/
SHELL_FILES := $(shell find . -name '*.sh' \
	-not -path './node_modules/*' \
	-not -path './.git/*' \
	-not -path './.config/tmux/plugins/*' \
	-not -path './.config/fish/functions/__sdkman-noexport-init.sh' \
	-not -path './scripts/attic/*' \
	-not -path './tests/run-init-tests.sh' 2>/dev/null)

FISH_FILES := $(shell find .config/fish -name '*.fish' 2>/dev/null)

lint: lint-shell lint-fish
	@echo "All linters passed."

lint-shell:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not installed — run: make install-lint-tools"; exit 1; fi
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt not installed — run: make install-lint-tools"; exit 1; fi
	@echo "==> shellcheck"
	@shellcheck -x -S warning $(SHELL_FILES)
	@echo "==> shfmt -i 4 -ci -d (diff only)"
	@shfmt -i 4 -ci -d $(SHELL_FILES)

lint-shell-fix:
	@command -v shfmt >/dev/null || { echo "shfmt not installed"; exit 1; }
	@echo "==> shfmt -i 4 -ci -w (writing)"
	@shfmt -i 4 -ci -w $(SHELL_FILES)

lint-fish:
	@command -v fish_indent >/dev/null || { echo "fish_indent not installed"; exit 1; }
	@echo "==> fish_indent --check (advisory; most files in functions/ are vendored)"
	@fish_indent --check $(FISH_FILES) || echo "(fish_indent reported issues — see above)"

test-lint: install-test-deps
	@./tests/run-tests.sh lint

install-lint-tools:
	@./scripts/inst/inst-lint-tools.sh

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

# Utility targets
kill-alacritty:
	@echo "Killing all Alacritty processes..."
	@pkill -9 alacritty 2>/dev/null || true
	@sleep 1
	@echo "Alacritty processes killed. Remaining count: $$(wmctrl -l | grep 'Alacritty' | wc -l)"
