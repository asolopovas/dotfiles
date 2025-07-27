# Dotfiles Project Makefile
.PHONY: help test-bash test-utility test-cleanup test-deps test-build clean-tests install-test-deps

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Testing:"
	@echo "  test-bash           Run all bash script tests"
	@echo "  test-utility        Test utility functions only"
	@echo "  test-cleanup        Test cleanup functions only"
	@echo "  test-deps           Test dependency installation only"
	@echo "  test-build          Test squid build process only"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean-tests         Clean up test artifacts"
	@echo "  install-test-deps   Install testing dependencies"
	@echo ""
	@echo "Usage: make <target>"

# Test targets
test-bash: install-test-deps
	@echo "Running comprehensive bash script tests..."
	@./tests/bash/run_all_tests.sh

test-utility: install-test-deps
	@echo "Testing utility functions..."
	@./tests/bash/test_utility_functions.sh

test-cleanup: install-test-deps
	@echo "Testing cleanup functions..."
	@./tests/bash/test_cleanup_functions.sh

test-deps: install-test-deps
	@echo "Testing dependency installation..."
	@./tests/bash/test_install_deps.sh

test-build: install-test-deps
	@echo "Testing squid build process..."
	@./tests/bash/test_build_squid.sh

# Maintenance targets
clean-tests:
	@echo "Cleaning test artifacts..."
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