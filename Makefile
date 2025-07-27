# Dotfiles Project Makefile
.PHONY: help test-bash clean-tests install-test-deps

# Default target
help:
	@echo "Dotfiles Project - Available targets:"
	@echo ""
	@echo "Testing:"
	@echo "  test-bash           Run all bash script tests"
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