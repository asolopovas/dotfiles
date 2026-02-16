#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# sync-ai.sh — Sync skills, MCP servers, and agents across AI CLIs
#
# Usage:
#   sync-ai.sh [sync]           Sync everything (default)
#   sync-ai.sh skills           Sync skills only
#   sync-ai.sh mcp              Sync MCP servers only
#   sync-ai.sh agents [sync]    Sync agents
#   sync-ai.sh agents add <url> Add an agent URL to config
#   sync-ai.sh agents remove <name>
#   sync-ai.sh agents list
#
# Environment:
#   SYNC_TARGETS     Comma-separated CLIs (default: auto-detect codex,claude,opencode)
#   AGENTS_CONFIG    Path to agents.conf
#   SKILL_INSTALLER  Path to skill-installer python script
#   OPENCODE_CONFIG  Path to opencode.json
#   CODEX_CONFIG     Path to codex config.toml
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

SKILL_SOURCES=(
    "https://github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/error-resolver"
    "https://github.com/lackeyjb/playwright-skill/tree/main/skills/playwright-skill"
    "https://github.com/microsoft/playwright-cli/tree/main/skills/playwright-cli"
    "https://github.com/mrgoonie/claudekit-skills/tree/main/.claude/skills/chrome-devtools"
)

declare -A MCP_SERVERS=(
    [context7]="npx @upstash/context7-mcp"
)

AGENTS_CONF="${AGENTS_CONFIG:-$DOTFILES_DIR/agents.conf}"
OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG:-}"
CODEX_CONFIG_FILE="${CODEX_CONFIG:-$HOME/.codex/config.toml}"

TARGETS=()

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

die() { echo "Error: $*" >&2; exit 1; }

have_cmd() { command -v "$1" &>/dev/null; }

require_cmd() { have_cmd "$1" || die "$1 not found in PATH."; }

trim() {
    local v="$1"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s' "$v"
}

normalize_key() {
    local name="${1,,}"
    name="${name//[^a-z0-9]/-}"
    printf '%s' "$name"
}

cli_home() {
    case "$1" in
        codex)    printf '%s' "${CODEX_HOME:-$HOME/.codex}" ;;
        claude)   printf '%s' "${CLAUDE_HOME:-$HOME/.claude}" ;;
        opencode) printf '%s' "${OPENCODE_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}" ;;
        *)        return 1 ;;
    esac
}

target_dir() {
    local home
    home=$(cli_home "$1") || return 1
    case "$2" in
        skills) printf '%s' "$home/skills" ;;
        agents)
            case "$1" in
                opencode) printf '%s' "$home/agent" ;;
                *)        printf '%s' "$home/agents" ;;
            esac ;;
        *) return 1 ;;
    esac
}

resolve_opencode_config_files() {
    if [[ -n "$OPENCODE_CONFIG_FILE" ]]; then
        printf '%s\n' "$OPENCODE_CONFIG_FILE"
        return 0
    fi

    local home
    home="$(cli_home opencode)"

    local primary="$home/opencode.json"
    local legacy="$home/config.json"
    local jsonc="$home/opencode.jsonc"

    if [[ -f "$primary" || -f "$legacy" || -f "$jsonc" ]]; then
        [[ -f "$primary" ]] && printf '%s\n' "$primary"
        [[ -f "$legacy" ]] && printf '%s\n' "$legacy"
        [[ -f "$jsonc" ]] && printf '%s\n' "$jsonc"
        return 0
    fi

    printf '%s\n' "$primary"
}

strip_jsonc_comments() {
    # Strip // and /* */ comments from JSONC, preserving strings.
    sed -e ':a' -e 's|//[^"]*$||' \
        -e 's|/\*.*\*/||g' "$1" | jq .
}

mcp_opencode_sync_file() {
    local config="$1"

    mkdir -p "$(dirname "$config")"

    if [[ ! -f "$config" ]]; then
        jq -n --arg schema_key '$schema' '{($schema_key): "https://opencode.ai/config.json", "mcp": {}}' > "$config"
    fi

    # For .jsonc files, strip comments so jq can parse them.
    if [[ "$config" == *.jsonc ]]; then
        if ! jq empty "$config" >/dev/null 2>&1; then
            strip_jsonc_comments "$config" > "$config.tmp" \
                && mv "$config.tmp" "$config" \
                || die "failed to strip comments from JSONC: $config"
        fi
    fi

    jq empty "$config" >/dev/null 2>&1 || die "invalid JSON in OpenCode config: $config"

    # Repair accidental invalid top-level key created by bad shell quoting.
    jq 'if has("") then if has("$schema") then del(.[""]) else .["$schema"] = .[""] | del(.[""]) end else . end' \
        "$config" > "$config.tmp" && mv "$config.tmp" "$config"

    # Remove servers not in MCP_SERVERS
    local name
    for name in $(jq -r '.mcp // {} | keys[]' "$config" 2>/dev/null); do
        [[ -v MCP_SERVERS[$name] ]] && continue
        jq --arg n "$name" 'del(.mcp[$n])' "$config" > "$config.tmp" \
            && mv "$config.tmp" "$config"
        echo "Removed $name from $config"
    done

    # Add/update servers
    local cmd entry
    local -a parts
    for name in "${!MCP_SERVERS[@]}"; do
        cmd="${MCP_SERVERS[$name]}"
        read -ra parts <<< "$cmd"
        entry=$(jq -n --arg name "$name" \
            --argjson cmd "$(printf '%s\n' "${parts[@]}" | jq -R . | jq -s .)" \
            '{($name): {type: "local", command: $cmd, enabled: true}}')
        jq --argjson entry "$entry" '.mcp //= {} | .mcp *= $entry' "$config" \
            > "$config.tmp" && mv "$config.tmp" "$config"
    done
}

# ---------------------------------------------------------------------------
# Target resolution
# ---------------------------------------------------------------------------

resolve_targets() {
    local raw="${SYNC_TARGETS:-}"
    local -a candidates=()

    if [[ -n "$raw" ]]; then
        IFS=', ' read -ra candidates <<< "$raw"
    else
        candidates=(codex claude opencode)
    fi

    local home
    for t in "${candidates[@]}"; do
        t=$(trim "${t,,}")
        [[ -n "$t" ]] || continue
        home=$(cli_home "$t" 2>/dev/null) || { echo "Warning: unknown target '$t'; skipping." >&2; continue; }
        if [[ -d "$home" ]] || have_cmd "$t"; then
            TARGETS+=("$t")
        else
            echo "Warning: $t not detected; skipping." >&2
        fi
    done

    (( ${#TARGETS[@]} )) || die "no supported CLI detected (codex, claude, opencode)."
}

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

resolve_skill_installer() {
    if [[ -n "${SKILL_INSTALLER:-}" ]]; then
        [[ -f "$SKILL_INSTALLER" ]] || die "skill-installer not found at $SKILL_INSTALLER"
        printf '%s' "$SKILL_INSTALLER"
        return 0
    fi

    local candidate
    for home in "$(cli_home codex)" "$(cli_home claude)"; do
        candidate="$home/skills/.system/skill-installer/scripts/install-skill-from-github.py"
        [[ -f "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
    done

    return 1
}

parse_github_skill_source() {
    local src="$1"
    local path
    path="${src#https://github.com/}"

    local owner repo kind rest ref subpath
    owner="${path%%/*}"
    rest="${path#*/}"
    repo="${rest%%/*}"
    rest="${rest#*/}"
    kind="${rest%%/*}"
    rest="${rest#*/}"
    ref="${rest%%/*}"
    subpath="${rest#*/}"

    [[ -n "$owner" && -n "$repo" && -n "$kind" && -n "$ref" && -n "$subpath" ]] || return 1
    [[ "$kind" == "tree" || "$kind" == "blob" ]] || return 1

    printf '%s|%s|%s|%s\n' "$owner" "$repo" "$ref" "$subpath"
}

install_skill_from_github_builtin() {
    local src="$1" dest_root="$2" key="$3"

    have_cmd git || die "git not found in PATH (required for built-in skill installer)."

    local parsed owner repo ref subpath
    parsed="$(parse_github_skill_source "$src")" || die "unsupported skill URL format: $src"
    IFS='|' read -r owner repo ref subpath <<< "$parsed"

    local tmp_dir tmp_repo src_dir dest_dir
    tmp_dir=$(mktemp -d)
    tmp_repo="$tmp_dir/repo"
    dest_dir="$dest_root/$key"

    rm -rf "$dest_dir"

    if ! git clone --depth 1 --filter=blob:none --sparse --branch "$ref" \
        "https://github.com/$owner/$repo.git" "$tmp_repo" >/dev/null 2>&1; then
        rm -rf "$tmp_dir"
        die "failed to clone $owner/$repo (ref: $ref)"
    fi

    if ! git -C "$tmp_repo" sparse-checkout set "$subpath" >/dev/null 2>&1; then
        rm -rf "$tmp_dir"
        die "failed to checkout '$subpath' from $owner/$repo"
    fi

    src_dir="$tmp_repo/$subpath"
    [[ -d "$src_dir" ]] || { rm -rf "$tmp_dir"; die "skill path not found in repo: $subpath"; }

    cp -R "$src_dir" "$dest_dir"
    if [[ ! -f "$dest_dir/SKILL.md" && -f "$dest_dir/skill.md" ]]; then
        mv "$dest_dir/skill.md" "$dest_dir/SKILL.md"
    fi

    [[ -f "$dest_dir/SKILL.md" ]] || { rm -rf "$tmp_dir"; die "skill install missing SKILL.md at $dest_dir"; }

    rm -rf "$tmp_dir"
}

normalize_skill_source() {
    local src="${1%%[#?]*}"
    if [[ -n "${SKILLS_REF:-}" ]]; then
        src="${src/\/tree\/main\//\/tree\/$SKILLS_REF/}"
        src="${src/\/blob\/main\//\/blob\/$SKILLS_REF/}"
    fi
    src="${src%/SKILL.md}"
    src="${src%/skill.md}"
    printf '%s' "$src"
}

skill_name_from_url() {
    local path="${1#*github.com/}"
    path="${path#*/}"   # strip owner
    path="${path#*/}"   # strip repo
    if [[ "$path" == tree/* || "$path" == blob/* ]]; then
        path="${path#*/}"   # strip tree|blob
        path="${path#*/}"   # strip branch
    fi
    path="${path%/}"
    path="${path%/SKILL.md}"
    path="${path%/skill.md}"
    printf '%s' "${path##*/}"
}

sync_skills() {
    local strict="${1:-false}"
    echo "--- Skills ---"
    require_cmd python3

    local installer
    local use_builtin="false"
    if ! installer="$(resolve_skill_installer)"; then
        if have_cmd git; then
            use_builtin="true"
            echo "-> skill-installer not found; using built-in GitHub installer"
        else
            if [[ "$strict" == "true" ]]; then
                die "skill-installer not found and git is unavailable (install git or set SKILL_INSTALLER)."
            fi
            echo "Warning: skill-installer not found and git unavailable; skipping skills sync." >&2
            return 0
        fi
    fi

    declare -A desired=()
    local src name
    for src in "${SKILL_SOURCES[@]}"; do
        src="$(normalize_skill_source "$src")"
        [[ "$src" == *github.com/* ]] || die "skill source must be a GitHub URL: $src"
        name="$(skill_name_from_url "$src")"
        [[ -n "$name" ]] || die "unable to resolve skill name from '$src'."
        desired["$name"]="$src"
    done

    local dest_root base dest_dir key
    for target in "${TARGETS[@]}"; do
        dest_root="$(target_dir "$target" skills)" || continue
        mkdir -p "$dest_root"

        # Remove skills not in desired set
        for installed in "$dest_root"/*/; do
            [[ -d "$installed" ]] || continue
            base="$(basename "$installed")"
            [[ "$base" == .* || ! -f "$installed/SKILL.md" ]] && continue
            if [[ -z "${desired[$base]:-}" ]]; then
                rm -rf "$installed"
                echo "Removed $base ($dest_root)"
            fi
        done

        # Install missing skills
        for key in "${!desired[@]}"; do
            dest_dir="$dest_root/$key"
            if [[ -d "$dest_dir" && -f "$dest_dir/SKILL.md" ]]; then
                echo "-> $key already installed in $dest_root"
                continue
            fi
            [[ -e "$dest_dir" ]] && rm -rf "$dest_dir"
            if [[ "$use_builtin" == "true" ]]; then
                install_skill_from_github_builtin "${desired[$key]}" "$dest_root" "$key"
            else
                python3 "$installer" --url "${desired[$key]}" --dest "$dest_root"
                [[ -f "$dest_dir/SKILL.md" ]] || die "skill install missing SKILL.md at $dest_dir"
            fi
        done
    done
}

# ---------------------------------------------------------------------------
# MCP Servers
# ---------------------------------------------------------------------------

mcp_opencode_sync() {
    require_cmd jq

    local config
    while IFS= read -r config; do
        [[ -n "$config" ]] || continue
        mcp_opencode_sync_file "$config"
    done < <(resolve_opencode_config_files)

    local home primary legacy
    home="$(cli_home opencode)"
    primary="$home/opencode.json"
    legacy="$home/config.json"
    if [[ ! -f "$primary" && -f "$legacy" ]]; then
        cp "$legacy" "$primary"
    fi
    if [[ -f "$primary" && ! -f "$legacy" ]]; then
        cp "$primary" "$legacy"
    fi
}

mcp_codex_sync() {
    local config="$CODEX_CONFIG_FILE"
    mkdir -p "$(dirname "$config")"

    local tmp="${config}.tmp"

    # Strip existing [mcp_servers.*] sections
    if [[ -f "$config" ]]; then
        awk '
            /^\[mcp_servers\./ { skip = 1; next }
            /^\[/              { skip = 0 }
            !skip
        ' "$config" > "$tmp"
        # Trim trailing blank lines
        sed -i -e :a -e '/^[[:space:]]*$/{ $d; N; ba; }' "$tmp"
    else
        : > "$tmp"
    fi

    [[ -s "$tmp" ]] && printf '\n\n' >> "$tmp"

    # Write server entries sorted by name
    local name cmd toml_cmd toml_args
    local -a parts
    for name in $(printf '%s\n' "${!MCP_SERVERS[@]}" | sort); do
        cmd="${MCP_SERVERS[$name]}"
        read -ra parts <<< "$cmd"
        toml_cmd=$(printf '%s' "${parts[0]}" | jq -R .)
        if (( ${#parts[@]} > 1 )); then
            toml_args=$(printf '%s\n' "${parts[@]:1}" | jq -R . | jq -s -c .)
        else
            toml_args="[]"
        fi
        printf '[mcp_servers.%s]\ncommand = %s\nargs = %s\n\n' \
            "$name" "$toml_cmd" "$toml_args" >> "$tmp"
    done

    mv "$tmp" "$config"
}

mcp_claude_sync() {
    require_cmd claude

    # Discover currently installed user-scope servers
    local -a installed=()
    local line
    while IFS= read -r line; do
        # claude mcp list output lines: "<name>: <command> - <status>"
        local name="${line%%:*}"
        name=$(trim "$name")
        [[ -n "$name" ]] && installed+=("$name")
    done < <(claude mcp list 2>/dev/null | grep -E '^[^ ].*:' || true)

    # Remove servers not in MCP_SERVERS
    local name
    for name in "${installed[@]}"; do
        [[ -v MCP_SERVERS[$name] ]] && continue
        claude mcp remove "$name" -s user 2>/dev/null \
            && echo "Removed $name from claude" \
            || echo "Warning: failed to remove $name from claude" >&2
    done

    # Add/update servers from MCP_SERVERS
    local cmd
    local -a parts
    for name in "${!MCP_SERVERS[@]}"; do
        cmd="${MCP_SERVERS[$name]}"
        read -ra parts <<< "$cmd"

        # Check if already installed
        if claude mcp get "$name" >/dev/null 2>&1; then
            # Remove and re-add to ensure config matches
            claude mcp remove "$name" -s user >/dev/null 2>&1 || true
        fi

        claude mcp add -s user -t stdio "$name" -- "${parts[@]}" >/dev/null 2>&1 \
            && echo "-> $name added to claude" \
            || echo "Warning: failed to add $name to claude" >&2
    done
}

sync_mcp() {
    echo "--- MCP Servers ---"

    for target in "${TARGETS[@]}"; do
        case "$target" in
            opencode) mcp_opencode_sync; echo "Synced MCP servers to opencode" ;;
            codex)    mcp_codex_sync;    echo "Synced MCP servers to codex" ;;
            claude)   mcp_claude_sync;   echo "Synced MCP servers to claude" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------

AGENT_SOURCES=()

load_agent_sources() {
    [[ -f "$AGENTS_CONF" ]] || return 0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(trim "$line")
        [[ -z "$line" || "$line" == \#* ]] && continue
        AGENT_SOURCES+=("$line")
    done < "$AGENTS_CONF"
}

apply_agent_overrides() {
    local file="$1" cli="$2"
    [[ "$cli" == "opencode" && -f "$file" ]] || return 0
    sed -i '/^model:/d' "$file" 2>/dev/null || true
}

resolve_agent_name() {
    local file="$1" name=""
    if [[ -f "$file" ]]; then
        name=$(sed -n '/^---$/,/^---$/s/^name: *//p' "$file" 2>/dev/null | head -1)
    fi
    [[ -z "$name" ]] && name=$(basename "$file" .md)
    normalize_key "$name"
}

download_agent() {
    local url="$1" dest_dir="$2"
    local tmp_file
    tmp_file=$(mktemp)

    if ! curl -fsSLo "$tmp_file" "$url" 2>/dev/null; then
        rm -f "$tmp_file"
        echo "Failed to download: $url" >&2
        return 1
    fi

    local filename
    filename=$(basename "$url")
    [[ "$filename" == *.md ]] || filename="${filename}.md"
    mv "$tmp_file" "$dest_dir/$filename"
    printf '%s' "$filename"
}

list_agents_in_dir() {
    local dest_dir="$1"
    [[ -d "$dest_dir" ]] || return 0
    local file name
    for file in "$dest_dir"/*.md; do
        [[ -f "$file" ]] || continue
        name=$(resolve_agent_name "$file")
        [[ -n "$name" ]] && echo "$name"
    done
}

sync_codex_agents_md() {
    local codex_home
    codex_home=$(cli_home codex)
    local agents_dir="$codex_home/agents"
    local agents_md="$codex_home/AGENTS.md"
    [[ -d "$agents_dir" ]] || return 0

    local file name
    {
        echo ""
        echo "## Custom Agents"
        echo ""
        for file in "$agents_dir"/*.md; do
            [[ -f "$file" ]] || continue
            name=$(resolve_agent_name "$file")
            [[ -n "$name" ]] || continue
            printf '### %s\n\n' "$name"
            cat "$file"
            printf '\n---\n\n'
        done
    } >> "$agents_md"
}

sync_agents() {
    echo "--- Agents ---"
    load_agent_sources

    if (( ${#AGENT_SOURCES[@]} == 0 )); then
        echo "No agent sources configured. Add URLs to $AGENTS_CONF or pass as arguments."
        return 0
    fi

    declare -A desired=()
    local src filename key
    for src in "${AGENT_SOURCES[@]}"; do
        src=$(trim "$src")
        [[ -n "$src" ]] || continue
        filename=$(basename "$src")
        key=$(normalize_key "${filename%.md}")
        [[ -n "$key" ]] || { echo "Warning: unable to resolve agent name from '$src'; skipping."; continue; }
        desired["$key"]="$src"
    done

    (( ${#desired[@]} )) || die "no valid agent sources found."

    local dest_dir
    for cli in "${TARGETS[@]}"; do
        dest_dir=$(target_dir "$cli" agents) || continue
        mkdir -p "$dest_dir"

        # Build current keys fresh for each target
        local -A current_keys=()
        local agent
        while IFS= read -r agent; do
            [[ -n "$agent" ]] && current_keys["$agent"]=1
        done < <(list_agents_in_dir "$dest_dir")

        for key in "${!desired[@]}"; do
            if [[ -z "${current_keys[$key]:-}" ]]; then
                echo "Installing $key for $cli..."
                if filename=$(download_agent "${desired[$key]}" "$dest_dir"); then
                    apply_agent_overrides "$dest_dir/$filename" "$cli"
                    echo "-> Installed $key ($cli)"
                else
                    echo "Warning: failed to install $key for $cli" >&2
                fi
            else
                echo "-> $key already installed ($cli)"
                apply_agent_overrides "$dest_dir/${key}.md" "$cli"
            fi
        done

        [[ "$cli" == "codex" ]] && sync_codex_agents_md
    done
}

agents_add() {
    local url="${1:-}"
    [[ -n "$url" ]] || die "URL required"

    if [[ ! -f "$AGENTS_CONF" ]]; then
        mkdir -p "$(dirname "$AGENTS_CONF")"
        printf '# Agent configuration — one URL per line\n\n' > "$AGENTS_CONF"
    fi

    grep -qF "$url" "$AGENTS_CONF" 2>/dev/null && { echo "Agent already in $AGENTS_CONF"; return 0; }
    echo "$url" >> "$AGENTS_CONF"
    echo "Added: $url — run 'sync-ai.sh agents sync' to install."
}

agents_remove() {
    local name="${1:-}"
    [[ -n "$name" ]] || die "Agent name required"
    [[ -f "$AGENTS_CONF" ]] || die "Config not found: $AGENTS_CONF"

    if ! grep -qF "$name" "$AGENTS_CONF" 2>/dev/null; then
        die "Agent not found: $name"
    fi

    local tmp
    tmp=$(mktemp)
    grep -vF "$name" "$AGENTS_CONF" > "$tmp" || true
    mv "$tmp" "$AGENTS_CONF"
    echo "Removed: $name — run 'sync-ai.sh agents sync' to update CLIs."
}

agents_list() {
    if [[ ! -f "$AGENTS_CONF" ]]; then
        echo "No agents configured."
        return 0
    fi
    echo "Configured agents:"
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(trim "$line")
        [[ -z "$line" || "$line" == \#* ]] && continue
        echo "  - $line"
    done < "$AGENTS_CONF"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  sync              Sync everything: skills, MCP servers, agents (default)
  skills            Sync skills only
  mcp               Sync MCP servers only
  agents [sub]      Manage agents (sync|add|remove|list)

Options:
  -h, --help        Show this help

Environment:
  SYNC_TARGETS      Comma-separated CLIs (default: codex,claude,opencode)
  AGENTS_CONFIG     Path to agents.conf (default: \$DOTFILES_DIR/agents.conf)
  OPENCODE_CONFIG   Path to opencode.json
  CODEX_CONFIG      Path to codex config.toml
EOF
    exit 0
}

main() {
    case "${1:-sync}" in
        -h|--help) usage ;;
        skills|mcp|sync)
            resolve_targets
            case "${1:-sync}" in
                sync)
                    sync_skills
                    sync_mcp
                    sync_agents
                    echo ""
                    echo "Done. Restart Codex, Claude, and OpenCode to pick up changes."
                    ;;
                skills) sync_skills true ;;
                mcp)    sync_mcp ;;
            esac
            ;;
        agents)
            shift
            case "${1:-sync}" in
                sync)       resolve_targets; sync_agents ;;
                add)        shift; agents_add "$@" ;;
                remove|rm)  shift; agents_remove "$@" ;;
                list|ls)    agents_list ;;
                *)          die "unknown agents command: $1" ;;
            esac
            ;;
        *) die "unknown command: $1" ;;
    esac
}

main "$@"
