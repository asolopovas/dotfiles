#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_ENABLED="${BATS_CACHE:-1}"

if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CACHE_DIR="$(git -C "$REPO_DIR" rev-parse --git-path pi-bats-cache)"
else
    CACHE_DIR="$REPO_DIR/.test-cache/pi-bats-cache"
fi
CACHE_DIR="${BATS_CACHE_DIR:-$CACHE_DIR}"

log() { printf '\033[0;32m%s\033[0m\n' "$*"; }
err() { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

DEFAULT_NAMES=(globals scripts init sync-ai inst-opencode lint)
ALL_NAMES=(globals scripts init sync-ai inst-opencode inst-picom lint)

declare -A SUITES=(
    [globals]="$SCRIPT_DIR/test-globals.bats"
    [scripts]="$SCRIPT_DIR/test-scripts.bats"
    [init]="$SCRIPT_DIR/test-init.bats"
    ["sync-ai"]="$SCRIPT_DIR/test-sync-ai.bats"
    ["inst-opencode"]="$SCRIPT_DIR/test-inst-opencode.bats"
    ["inst-picom"]="$SCRIPT_DIR/test-inst-picom.bats"
    [lint]="$SCRIPT_DIR/test-lint.bats"
)

usage() {
    echo "Usage: $0 [--changed file ...|--list-changed file ...|globals|scripts|init|sync-ai|inst-opencode|inst-picom|lint ...|-f pattern]"
}

rel_hash() {
    local file abs
    for file in "$@"; do
        abs="$REPO_DIR/$file"
        printf 'path %s\n' "$file"
        if [ -e "$abs" ] || [ -L "$abs" ]; then
            sha256sum "$abs" 2>/dev/null || printf 'unreadable\n'
        else
            printf 'missing\n'
        fi
    done
}

shell_files() {
    cd "$REPO_DIR"
    {
        find . -name '*.sh' \
            -not -path './node_modules/*' \
            -not -path './.git/*' \
            -not -path './.config/tmux/plugins/*' \
            -not -path './.config/fish/functions/__sdkman-noexport-init.sh' \
            -not -path './scripts/attic/*' \
            -not -path './tests/run-init-tests.sh' 2>/dev/null
        [ -f .githooks/pre-commit ] && printf '%s\n' ./.githooks/pre-commit
    } | LC_ALL=C sort | sed 's#^./##'
}

tool_info() {
    local tool="$1"
    if command -v "$tool" >/dev/null 2>&1; then
        printf 'tool %s %s\n' "$tool" "$(command -v "$tool")"
        "$tool" --version 2>&1 | head -n 3 || true
    else
        printf 'tool %s missing\n' "$tool"
    fi
}

suite_deps() {
    local name="$1"
    case "$name" in
        globals)
            printf '%s\n' tests/test-globals.bats globals.sh
            ;;
        scripts)
            printf '%s\n' tests/test-scripts.bats scripts/ops/ops-update-symlinks.sh env/include-paths.sh env/env-vars.sh .profile helpers/ls-path helpers/fzf-code
            ;;
        init)
            printf '%s\n' tests/test-init.bats init.sh globals.sh scripts/inst/inst-bun.sh scripts/inst/inst-deno.sh scripts/inst/inst-fd.sh scripts/inst/inst-fish.sh scripts/inst/inst-fzf.sh scripts/inst/inst-cargo.sh scripts/cfg-default-dirs.sh scripts/inst/inst-nvim.sh
            ;;
        sync-ai)
            printf '%s\n' tests/test-sync-ai.bats scripts/sync-ai.sh
            ;;
        inst-opencode)
            printf '%s\n' tests/test-inst-opencode.bats scripts/inst/inst-opencode.sh
            ;;
        inst-picom)
            printf '%s\n' tests/test-inst-picom.bats scripts/inst/inst-picom.sh
            ;;
        lint)
            printf '%s\n' tests/test-lint.bats .config/fish/config.fish .config/fish/functions/gr.fish .config/fish/functions/gtp.fish .config/fish/functions/nvm_get_arch.fish
            shell_files
            ;;
    esac
}

suite_exists() {
    local name
    for name in "${ALL_NAMES[@]}"; do
        [ "$name" = "$1" ] && return 0
    done
    return 1
}

path_in_suite_deps() {
    local name="$1" file="$2" dep
    while IFS= read -r dep; do
        [ "$dep" = "$file" ] && return 0
    done < <(suite_deps "$name")
    return 1
}

is_lint_path() {
    case "$1" in
        *.sh | .githooks/pre-commit | .config/fish/config.fish | .config/fish/functions/gr.fish | .config/fish/functions/gtp.fish | .config/fish/functions/nvm_get_arch.fish)
            return 0
            ;;
    esac
    return 1
}

changed_suite_names() {
    local file name all=0
    declare -A needs=()
    for file in "$@"; do
        case "$file" in
            tests/run-tests.sh)
                all=1
                ;;
        esac
        if is_lint_path "$file"; then
            needs[lint]=1
        fi
        for name in "${ALL_NAMES[@]}"; do
            if path_in_suite_deps "$name" "$file"; then
                needs[$name]=1
            fi
        done
    done
    if [ "$all" -eq 1 ]; then
        printf '%s\n' "${ALL_NAMES[@]}"
        return
    fi
    for name in "${ALL_NAMES[@]}"; do
        if [ "${needs[$name]+set}" = set ]; then
            printf '%s\n' "$name"
        fi
    done
}

suite_key() {
    local name="$1"
    {
        printf 'suite %s\n' "$name"
        printf 'runner\n'
        sha256sum "$SCRIPT_DIR/run-tests.sh"
        printf 'bash %s\n' "$BASH_VERSION"
        bats --version
        printf 'uname %s %s\n' "$(uname -s)" "$(uname -m)"
        [ -f /etc/os-release ] && sha256sum /etc/os-release || true
        suite_deps "$name" | while IFS= read -r dep; do rel_hash "$dep"; done
        case "$name" in
            scripts)
                tool_info sqlite3
                ;;
            lint)
                tool_info shellcheck
                tool_info shfmt
                tool_info fish_indent
                ;;
        esac
    } | sha256sum | awk '{print $1}'
}

cache_file() {
    printf '%s/%s.sha256\n' "$CACHE_DIR" "$1"
}

cache_hit() {
    local name="$1" key="$2" file
    [ "$CACHE_ENABLED" = 1 ] || return 1
    file="$(cache_file "$name")"
    [ -f "$file" ] && [ "$(<"$file")" = "$key" ]
}

cache_record() {
    local name="$1" key="$2"
    [ "$CACHE_ENABLED" = 1 ] || return 0
    mkdir -p "$CACHE_DIR"
    printf '%s\n' "$key" >"$(cache_file "$name")"
}

parallel_jobs() {
    if [ -n "${BATS_JOBS:-}" ]; then
        printf '%s\n' "$BATS_JOBS"
        return
    fi
    local jobs=2
    if command -v nproc >/dev/null 2>&1; then
        jobs="$(nproc)"
    elif command -v sysctl >/dev/null 2>&1; then
        jobs="$(sysctl -n hw.ncpu 2>/dev/null || printf '2')"
    fi
    [ "$jobs" -gt 8 ] && jobs=8
    [ "$jobs" -lt 2 ] && jobs=2
    printf '%s\n' "$jobs"
}

can_parallel() {
    command -v parallel >/dev/null 2>&1 || command -v rush >/dev/null 2>&1
}

run_bats() {
    if [ "$#" -gt 1 ] && can_parallel; then
        bats -j "$(parallel_jobs)" --no-parallelize-within-files "$@"
    else
        local suite
        for suite in "$@"; do
            bats "$suite"
        done
    fi
}

selected_names=()
if [ "${1:-}" = "--list-changed" ]; then
    shift
    if [ "$#" -gt 0 ]; then
        changed_suite_names "$@"
    fi
    exit 0
elif [ "${1:-}" = "--changed" ]; then
    shift
    if [ "$#" -gt 0 ]; then
        while IFS= read -r name; do
            selected_names+=("$name")
        done < <(changed_suite_names "$@")
    fi
elif [[ "${1:-}" = -* ]]; then
    if ! command -v bats >/dev/null 2>&1; then
        err "bats not found. Install: sudo apt install bats"
        exit 1
    fi
    exec bats "$@" "$SCRIPT_DIR/test-globals.bats" "$SCRIPT_DIR/test-scripts.bats" "$SCRIPT_DIR/test-init.bats" "$SCRIPT_DIR/test-sync-ai.bats" "$SCRIPT_DIR/test-inst-opencode.bats" "$SCRIPT_DIR/test-lint.bats"
elif [ "$#" -eq 0 ]; then
    selected_names=("${DEFAULT_NAMES[@]}")
else
    for name in "$@"; do
        if suite_exists "$name"; then
            selected_names+=("$name")
        else
            err "Unknown suite: $name"
            usage
            exit 1
        fi
    done
fi

if [ "${#selected_names[@]}" -eq 0 ]; then
    log "RESULT: 0/0 suites selected"
    exit 0
fi

if ! command -v bats >/dev/null 2>&1; then
    err "bats not found. Install: sudo apt install bats"
    exit 1
fi

declare -A keys=()
to_run_names=()
to_run_files=()
cached=0

for name in "${selected_names[@]}"; do
    key=""
    if [ "$CACHE_ENABLED" = 1 ]; then
        key="$(suite_key "$name")"
        keys[$name]="$key"
    fi
    if [ "$CACHE_ENABLED" = 1 ] && cache_hit "$name" "$key"; then
        log "--- test-$name (cached) ---"
        cached=$((cached + 1))
    else
        to_run_names+=("$name")
        to_run_files+=("${SUITES[$name]}")
    fi
done

if [ "${#to_run_files[@]}" -gt 0 ]; then
    if [ "${#to_run_files[@]}" -eq 1 ]; then
        log "--- test-${to_run_names[0]} ---"
    else
        log "--- running ${#to_run_files[@]} suite(s) ---"
    fi
    run_bats "${to_run_files[@]}"
    if [ "$CACHE_ENABLED" = 1 ]; then
        for name in "${to_run_names[@]}"; do
            cache_record "$name" "${keys[$name]}"
        done
    fi
fi

total=${#selected_names[@]}
echo ""
if [ "$cached" -gt 0 ]; then
    log "RESULT: $total/$total suites passed ($cached cached)"
else
    log "RESULT: $total/$total suites passed"
fi
