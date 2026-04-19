#!/usr/bin/env bats

# Lint sanity checks. Each test skips cleanly if the underlying tool isn't
# installed — keeps `make test` green on machines without lint tooling.
# Install all tools with: make install-lint-tools

setup() {
    REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    cd "$REPO_DIR"

    SHELL_FILES=()
    while IFS= read -r f; do
        SHELL_FILES+=("$f")
    done < <(find . -name '*.sh' \
        -not -path './node_modules/*' \
        -not -path './.git/*' \
        -not -path './.config/tmux/plugins/*' \
        -not -path './.config/fish/functions/__sdkman-noexport-init.sh' \
        -not -path './scripts/attic/*' \
        -not -path './tests/run-init-tests.sh' 2>/dev/null)

    FISH_FILES=()
    while IFS= read -r f; do
        FISH_FILES+=("$f")
    done < <(find .config/fish -name '*.fish' 2>/dev/null)
}

@test "shellcheck: all *.sh pass at warning level" {
    command -v shellcheck >/dev/null || skip "shellcheck not installed (make install-lint-tools)"
    [ "${#SHELL_FILES[@]}" -gt 0 ] || skip "no shell files found"
    run shellcheck -x -S warning "${SHELL_FILES[@]}"
    [ "$status" -eq 0 ]
}

@test "shfmt: all *.sh match canonical formatting (4-space, switch-case indent)" {
    command -v shfmt >/dev/null || skip "shfmt not installed (make install-lint-tools)"
    [ "${#SHELL_FILES[@]}" -gt 0 ] || skip "no shell files found"
    run shfmt -i 4 -ci -d "${SHELL_FILES[@]}"
    [ "$status" -eq 0 ]
}

@test "fish_indent: project-owned fish files are formatted" {
    command -v fish_indent >/dev/null || skip "fish_indent not installed"
    # Most of .config/fish/functions/ is vendored (fisher, fzf, nvm, sdk,
    # prompt). Only check files we author ourselves.
    local owned=(
        ".config/fish/config.fish"
        ".config/fish/functions/gr.fish"
        ".config/fish/functions/gtp.fish"
        ".config/fish/functions/nvm_get_arch.fish"
    )
    local present=()
    for f in "${owned[@]}"; do [ -f "$f" ] && present+=("$f"); done
    [ "${#present[@]}" -gt 0 ] || skip "no owned fish files present"
    run fish_indent --check "${present[@]}"
    [ "$status" -eq 0 ]
}

@test "no script uses /bin/sh shebang" {
    [ "${#SHELL_FILES[@]}" -gt 0 ] || skip "no shell files found"
    local bad=()
    for f in "${SHELL_FILES[@]}"; do
        IFS= read -r line < "$f" || true
        [ "$line" = "#!/bin/sh" ] && bad+=("$f")
    done
    if [ "${#bad[@]}" -gt 0 ]; then
        printf '/bin/sh shebang in: %s\n' "${bad[@]}" >&2
        return 1
    fi
}

@test "no trailing whitespace in shell scripts" {
    [ "${#SHELL_FILES[@]}" -gt 0 ] || skip "no shell files found"
    run grep -nE ' +$' "${SHELL_FILES[@]}"
    [ "$status" -ne 0 ]
}
