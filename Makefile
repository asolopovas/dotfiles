# Dotfiles Project Makefile
.PHONY: help test-bash clean-tests install-test-deps install-squid test-squid uninstall-squid

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
	@echo "  uninstall-squid     Remove Squid installation (keeps build for reuse)"
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
			env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
			sudo -E env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
			apt-get update -qq && sudo apt-get install -y gum; \
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
		env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
		sudo -E env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
		./scripts/install-squid.sh --install-only; \
	else \
		echo "Installing Squid proxy and configuring all development tools..."; \
		env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
		sudo -E env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
		./scripts/install-squid.sh; \
	fi

test-squid: install-squid
	@echo "Testing complete Squid proxy setup and dev environment caching..."
	@echo ""
	@echo "=== Basic Proxy Tests ==="
	@echo "Testing systemd service:"
	@if systemctl is-active squid >/dev/null 2>&1; then \
		echo "✓ Squid service is running"; \
	else \
		echo "❌ Squid service failed"; \
		echo "Attempting to start squid..."; \
		sudo systemctl start squid; \
		sleep 3; \
		if systemctl is-active squid >/dev/null 2>&1; then \
			echo "✓ Squid service started successfully"; \
		else \
			echo "❌ Failed to start squid service"; \
			sudo journalctl -u squid --no-pager -n 10; \
			exit 1; \
		fi \
	fi
	@echo ""
	@echo "Testing proxy connectivity:"
	@# Wait for squid to be ready
	@retries=0; while ! netstat -tlnp 2>/dev/null | grep -q ":3128.*LISTEN" && [ $$retries -lt 10 ]; do \
		echo "Waiting for squid to listen on port 3128..."; \
		sleep 1; \
		retries=$$((retries + 1)); \
	done
	@if ! netstat -tlnp 2>/dev/null | grep -q ":3128.*LISTEN"; then \
		echo "❌ Squid is not listening on port 3128"; \
		exit 1; \
	fi
	@# Test HTTP proxy
	@if timeout 10 curl -s --proxy http://localhost:3128 --connect-timeout 5 http://httpbin.org/get >/dev/null 2>&1; then \
		echo "✓ HTTP proxy working"; \
	else \
		echo "❌ HTTP proxy test failed"; \
		echo "Debug: Testing direct connection..."; \
		if timeout 5 curl -s --connect-timeout 3 http://httpbin.org/get >/dev/null 2>&1; then \
			echo "Direct connection works, proxy issue"; \
		else \
			echo "Network connectivity issue"; \
		fi; \
	fi
	@# Test HTTPS proxy  
	@if timeout 10 curl -s --proxy http://localhost:3128 --connect-timeout 5 https://httpbin.org/get >/dev/null 2>&1; then \
		echo "✓ HTTPS proxy working"; \
	else \
		echo "❌ HTTPS proxy test failed"; \
	fi
	@echo ""
	@echo "=== Environment Configuration Tests ==="
	@echo "Checking global proxy environment:"
	@grep -q "HTTP_PROXY" /etc/environment.d/99-proxy.conf 2>/dev/null && echo "✓ Global proxy environment configured" || echo "❌ Global proxy environment missing"
	@test -f /etc/profile.d/proxy.sh && echo "✓ Shell profile proxy configured" || echo "❌ Shell profile proxy missing"
	@test -f /etc/fish/conf.d/proxy.fish && echo "✓ Fish shell proxy configured" || echo "❌ Fish shell proxy missing"
	@echo ""
	@echo "=== Development Tool Cache Tests ==="
	@echo "Testing common development tools with proxy caching:"
	@echo -n "• wget: "; wget -q --proxy=on -e use_proxy=yes -e http_proxy=http://localhost:3128 -O /dev/null http://httpbin.org/get 2>/dev/null && echo "✓ cached" || echo "❌ failed"
	@echo -n "• curl with env: "; env http_proxy=http://localhost:3128 https_proxy=http://localhost:3128 curl -s http://httpbin.org/get >/dev/null 2>&1 && echo "✓ cached" || echo "❌ failed"
	@if command -v npm >/dev/null 2>&1; then \
		echo -n "• npm: "; npm config get proxy >/dev/null 2>&1 && echo "✓ proxy configured" || echo "⚠ run: npm config set proxy http://localhost:3128"; \
	fi
	@if command -v pip >/dev/null 2>&1; then \
		echo -n "• pip: "; pip config list | grep -q proxy 2>/dev/null && echo "✓ proxy configured" || echo "⚠ add [global] proxy=http://localhost:3128 to ~/.pip/pip.conf"; \
	fi
	@if command -v docker >/dev/null 2>&1; then \
		echo -n "• docker: "; test -f ~/.docker/config.json && grep -qi proxies ~/.docker/config.json 2>/dev/null && echo "✓ proxy configured" || echo "⚠ configure docker daemon proxy"; \
	fi
	@echo ""
	@echo "=== Cache Performance Test ==="
	@echo "Testing cache hit performance (downloading same file twice):"
	@# Use a larger static file that's more likely to be cached
	@cache_url="http://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png"; \
	echo "Downloading test file: $$cache_url"; \
	start_time=$$(date +%s%N); \
	timeout 15 curl -s --proxy http://localhost:3128 --connect-timeout 5 "$$cache_url" -o /tmp/cache-test-1.tmp 2>&1; \
	first_time=$$(( ($$(date +%s%N) - $$start_time) / 1000000 )); \
	sleep 1; \
	start_time=$$(date +%s%N); \
	timeout 15 curl -s --proxy http://localhost:3128 --connect-timeout 5 "$$cache_url" -o /tmp/cache-test-2.tmp 2>&1; \
	second_time=$$(( ($$(date +%s%N) - $$start_time) / 1000000 )); \
	rm -f /tmp/cache-test-*.tmp; \
	echo "First request: $${first_time}ms, Second request: $${second_time}ms"; \
	if [ $$second_time -lt $$((first_time / 2)) ]; then \
		echo "✓ Cache acceleration working (>50% improvement)"; \
	elif [ $$second_time -lt $$first_time ]; then \
		echo "✓ Cache working ($$((100 - (second_time * 100 / first_time)))% improvement)"; \
	else \
		echo "⚠ Cache may not be accelerating requests (check squid logs)"; \
	fi
	@echo ""
	@echo "=== Development Tools Proxy Tests ==="
	@sudo ./scripts/install-squid.sh --test-tools
	@echo ""
	@echo "=== Git Clone Test ==="
	@sudo ./scripts/install-squid.sh --test-git-clone ~/src
	@echo ""
	@echo "✓ Squid proxy setup test complete"
	@echo "Note: You may need to restart your session for global proxy to take effect"

uninstall-squid:
	@echo "Removing Squid proxy from system (preserving build)..."
	@sudo ./scripts/install-squid.sh --uninstall
	@echo "✓ Squid proxy removed from system"
	@echo "Note: Build remains available for future installations"