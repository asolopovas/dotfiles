# WordPress test-login targets (recipes use TABS). Usage: make wp-login WP=/path/to/wp
WP    ?= .
SKILL := $(HOME)/.agents/skills/wordpress-test-login/scripts

.PHONY: wp-login wp-clean

## Provision test admin + log into wp-admin via Playwright.
wp-login:
	bash $(SKILL)/wp-test-login.sh $(WP)

## Remove the test user and stored credentials.
wp-clean:
	wp --path=$(WP) user delete pi-test-admin --reassign=1 --yes
	rm -f "$${XDG_DATA_HOME:-$$HOME/.local/share}/wp-test-auth/$$(wp --path=$(WP) option get siteurl | sed -E 's#^https?://##; s#/.*##').env"
