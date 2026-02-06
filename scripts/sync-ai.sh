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
#   SKILLS_TARGETS / SKILLS_CLI  Comma-separated CLIs (default: codex,claude,opencode)
#   AGENTS_CLI                   Comma-separated CLIs for agents
#   AGENTS_CONFIG                Path to agents.conf
#   SKILL_INSTALLER              Path to skill-installer python script
#   OPENCODE_CONFIG              Path to opencode.json
#   CODEX_CONFIG                 Path to codex config.toml
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SKILL_SOURCES=(
    "https://github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/error-resolver"
    "https://github.com/lackeyjb/playwright-skill/tree/main/skills/playwright-skill"
    "https://github.com/mrgoonie/claudekit-skills/tree/main/.claude/skills/chrome-devtools"
)

declare -A MCP_SERVERS=(
    [context7]="npx @upstash/context7-mcp"
    [git]="npx @cyanheads/git-mcp-server"
    [github]="npx @modelcontextprotocol/server-github"
    [chrome-devtools]="npx -y chrome-devtools-mcp --browser-url=http://127.0.0.1:9222"
)

AGENTS_CONF="${AGENTS_CONFIG:-$HOME/dotfiles/config/agents.conf}"
OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
CODEX_CONFIG_FILE="${CODEX_CONFIG:-$HOME/.codex/config.toml}"

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

die() { echo "Error: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

trim() {
    local v="$1"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s' "$v"
}

normalize_key() {
    local name="${1,,}"
    name="${name//[^a-z0-9]/-}"
    echo "$name"
}

# ---------------------------------------------------------------------------
# Target resolution (shared across all subsystems)
# ---------------------------------------------------------------------------

resolve_targets() {
    local raw="${SKILLS_TARGETS:-${SKILLS_CLI:-${AGENTS_CLI:-}}}"
    local -a candidates=() resolved=()

    if [[ -n "$raw" ]]; then
        raw="${raw//,/ }"
        read -ra candidates <<< "$raw"
    else
        candidates=(codex claude opencode)
    fi

    for t in "${candidates[@]}"; do
        [[ -n "$t" ]] || continue
        case "${t,,}" in
            codex)
                if [[ -d "${CODEX_HOME:-$HOME/.codex}" ]] || have_cmd codex; then
                    resolved+=("codex")
                elif [[ -n "$raw" ]]; then
                    echo "Warning: codex not detected; skipping." >&2
                fi ;;
            claude)
                if [[ -d "${CLAUDE_HOME:-$HOME/.claude}" ]] || have_cmd claude; then
                    resolved+=("claude")
                elif [[ -n "$raw" ]]; then
                    echo "Warning: claude not detected; skipping." >&2
                fi ;;
            opencode)
                if [[ -d "${OPENCODE_HOME:-$HOME/.config/opencode}" ]] || have_cmd opencode; then
                    resolved+=("opencode")
                elif [[ -n "$raw" ]]; then
                    echo "Warning: opencode not detected; skipping." >&2
                fi ;;
            *) echo "Warning: unknown target '$t'; skipping." >&2 ;;
        esac
    done

    [[ ${#resolved[@]} -gt 0 ]] || die "no supported CLI detected (codex, claude, opencode)."
    printf '%s\n' "${resolved[@]}"
}

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

skills_target_root() {
    case "$1" in
        codex)    echo "${CODEX_HOME:-$HOME/.codex}/skills" ;;
        claude)   echo "${CLAUDE_HOME:-$HOME/.claude}/skills" ;;
        opencode) echo "${OPENCODE_HOME:-$HOME/.config/opencode}/skills" ;;
        *)        return 1 ;;
    esac
}

resolve_skill_installer() {
    if [[ -n "${SKILL_INSTALLER:-}" ]]; then
        [[ -f "$SKILL_INSTALLER" ]] || die "skill-installer not found at $SKILL_INSTALLER"
        printf '%s\n' "$SKILL_INSTALLER"
        return 0
    fi

    local -a homes=(
        "${CODEX_HOME:-$HOME/.codex}"
        "${CLAUDE_HOME:-$HOME/.claude}"
    )
    for home in "${homes[@]}"; do
        local c="$home/skills/.system/skill-installer/scripts/install-skill-from-github.py"
        [[ -f "$c" ]] && { printf '%s\n' "$c"; return 0; }
    done

    die "skill-installer not found (set SKILL_INSTALLER or install skill-installer)."
}

normalize_skill_source() {
    local src="$1"
    src="${src%%\#*}"; src="${src%%\?*}"
    if [[ -n "${SKILLS_REF:-}" ]]; then
        src="${src/\/tree\/main\//\/tree\/$SKILLS_REF/}"
        src="${src/\/blob\/main\//\/blob\/$SKILLS_REF/}"
    fi
    [[ "$src" == */SKILL.md ]] && src="${src%/SKILL.md}"
    [[ "$src" == */skill.md ]] && src="${src%/skill.md}"
    printf '%s\n' "$src"
}

skill_name_from_url() {
    local url="$1" path="${1#*github.com/}"
    path="${path#*/}"; path="${path#*/}"
    [[ "$path" == tree/* || "$path" == blob/* ]] && { path="${path#*/}"; path="${path#*/}"; }
    path="${path%/}"; path="${path%/SKILL.md}"; path="${path%/skill.md}"
    printf '%s\n' "${path##*/}"
}

sync_skills() {
    echo "--- Skills ---"
    have_cmd python3 || die "python3 not found in PATH."

    local installer
    installer="$(resolve_skill_installer)"
    mapfile -t targets < <(resolve_targets)

    declare -A desired=()
    for src in "${SKILL_SOURCES[@]}"; do
        src="$(normalize_skill_source "$src")"
        [[ "$src" == *github.com/* ]] || die "skill source must be a GitHub URL: $src"
        local name
        name="$(skill_name_from_url "$src")"
        [[ -n "$name" ]] || die "unable to resolve skill name from '$src'."
        desired["$name"]="$src"
    done

    for target in "${targets[@]}"; do
        local dest_root
        dest_root="$(skills_target_root "$target")" || continue
        mkdir -p "$dest_root"

        # Remove skills no longer desired
        for installed in "$dest_root"/*; do
            [[ -d "$installed" ]] || continue
            local base
            base="$(basename "$installed")"
            [[ "$base" == .* ]] && continue
            [[ -f "$installed/SKILL.md" ]] || continue
            if [[ -z "${desired[$base]:-}" ]]; then
                rm -rf "$installed"
                echo "Removed $base ($dest_root)"
            fi
        done

        # Install missing skills
        for key in "${!desired[@]}"; do
            local dest_dir="$dest_root/$key"
            if [[ -e "$dest_dir" ]]; then
                if [[ -f "$dest_dir/SKILL.md" ]]; then
                    echo "-> $key already installed in $dest_root"
                    continue
                fi
                echo "-> $key missing SKILL.md in $dest_root; reinstalling"
                rm -rf "$dest_dir"
            fi
            python3 "$installer" --url "${desired[$key]}" --dest "$dest_root"
            [[ -f "$dest_dir/SKILL.md" ]] || die "skill install missing SKILL.md at $dest_dir"
        done
    done
}

# ---------------------------------------------------------------------------
# MCP Servers
# ---------------------------------------------------------------------------

mcp_opencode_sync() {
    local config="$OPENCODE_CONFIG_FILE"
    [[ -f "$config" ]] || return 0

    have_cmd jq || die "jq not found in PATH."

    # Remove servers not in MCP_SERVERS
    local current
    current=$(jq -r '.mcp | keys[]' "$config" 2>/dev/null || true)
    for name in $current; do
        [[ -v MCP_SERVERS[$name] ]] || {
            jq --arg n "$name" 'del(.mcp[$n])' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
        }
    done

    # Add/update each server
    for name in "${!MCP_SERVERS[@]}"; do
        local cmd="${MCP_SERVERS[$name]}"
        local -a parts
        read -ra parts <<< "$cmd"
        local entry
        entry=$(jq -n --arg name "$name" \
            --argjson cmd "$(printf '%s\n' "${parts[@]}" | jq -R . | jq -s .)" \
            '{($name): {type: "local", command: $cmd, enabled: true}}')
        jq --argjson entry "$entry" '.mcp //= {} | .mcp *= $entry' "$config" \
            > "$config.tmp" && mv "$config.tmp" "$config"
    done
}

mcp_codex_sync() {
    local config="$CODEX_CONFIG_FILE"
    local config_dir
    config_dir=$(dirname "$config")
    mkdir -p "$config_dir"

    local tmp="${config}.tmp"

    # Strip all existing [mcp_servers.*] blocks
    if [[ -f "$config" ]]; then
        awk '
            BEGIN { skip = 0 }
            /^\[mcp_servers\./ { skip = 1; next }
            /^\[.*\]/ { if (skip) { skip = 0; print; next } }
            skip == 0 { print }
        ' "$config" > "$tmp"
    else
        : > "$tmp"
    fi

    [[ -s "$tmp" ]] && printf '\n' >> "$tmp"

    # Write each server as a TOML block
    for name in $(printf '%s\n' "${!MCP_SERVERS[@]}" | sort); do
        local cmd="${MCP_SERVERS[$name]}"
        local -a parts
        read -ra parts <<< "$cmd"
        local toml_cmd toml_args
        toml_cmd=$(printf '%s' "${parts[0]}" | jq -R .)
        toml_args=$(printf '%s\n' "${parts[@]:1}" | jq -R . | jq -s -c .)

        printf '[mcp_servers.%s]\n' "$name" >> "$tmp"
        printf 'command = %s\n' "$toml_cmd" >> "$tmp"
        printf 'args = %s\n\n' "$toml_args" >> "$tmp"
    done

    mv "$tmp" "$config"
}

sync_mcp() {
    echo "--- MCP Servers ---"
    have_cmd jq || die "jq not found in PATH."

    mapfile -t targets < <(resolve_targets)

    for target in "${targets[@]}"; do
        case "$target" in
            opencode) mcp_opencode_sync; echo "Synced MCP servers to opencode" ;;
            codex)    mcp_codex_sync;    echo "Synced MCP servers to codex" ;;
            claude)   echo "Note: Claude Code MCP managed via settings.json, skipping." ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------

AGENT_SOURCES=()

load_agent_sources() {
    if [[ -f "$AGENTS_CONF" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim "$line")
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            AGENT_SOURCES+=("$line")
        done < "$AGENTS_CONF"
    fi
}

agents_target_root() {
    case "$1" in
        claude)   echo "${CLAUDE_HOME:-$HOME/.claude}/agents" ;;
        codex)    echo "${CODEX_HOME:-$HOME/.codex}/agents" ;;
        opencode) echo "${OPENCODE_HOME:-$HOME/.config/opencode}/agent" ;;
        *)        return 1 ;;
    esac
}

apply_agent_overrides() {
    local file="$1" cli="$2"
    [[ "$cli" == "opencode" && -f "$file" ]] && sed -i '/^model:/d' "$file" 2>/dev/null || true
}

resolve_agent_name() {
    local file="$1" name=""
    [[ -f "$file" ]] && name=$(sed -n '/^---$/,/^---$/s/^name: *//p' "$file" 2>/dev/null | head -1)
    [[ -z "$name" ]] && name=$(basename "$file" .md | sed 's/\.md$//')
    printf '%s' "$(normalize_key "$name")"
}

download_agent() {
    local url="$1" dest_dir="$2"
    local tmp_dir filename
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" RETURN

    curl -fsSLo "$tmp_dir/downloaded" "$url" 2>/dev/null || { echo "Failed to download: $url" >&2; return 1; }
    filename=$(basename "$url")
    [[ "$filename" == *.md ]] || filename="${filename}.md"
    mv "$tmp_dir/downloaded" "$dest_dir/$filename"
    printf '%s' "$filename"
}

list_agents_in_dir() {
    local dest_dir="$1"
    [[ -d "$dest_dir" ]] || return
    for file in "$dest_dir"/*.md; do
        [[ -f "$file" ]] || continue
        local name
        name=$(resolve_agent_name "$file")
        [[ -n "$name" ]] && echo "$name"
    done
}

sync_codex_agents_md() {
    local codex_home="${CODEX_HOME:-$HOME/.codex}"
    local agents_dir="$codex_home/agents"
    local agents_md="$codex_home/AGENTS.md"

    [[ -d "$agents_dir" ]] || return 0

    {
        echo ""
        echo "## Custom Agents"
        echo ""
        for file in "$agents_dir"/*.md; do
            [[ -f "$file" ]] || continue
            local name
            name=$(resolve_agent_name "$file")
            if [[ -n "$name" ]]; then
                echo "### $name"
                echo ""
                cat "$file"
                echo ""
                echo "---"
                echo ""
            fi
        done
    } >> "$agents_md"
}

sync_agents() {
    echo "--- Agents ---"
    load_agent_sources

    if [[ ${#AGENT_SOURCES[@]} -eq 0 ]]; then
        echo "No agent sources configured. Add URLs to $AGENTS_CONF or pass as arguments."
        return 0
    fi

    mapfile -t targets < <(resolve_targets)

    declare -A desired=()
    for src in "${AGENT_SOURCES[@]}"; do
        src=$(trim "$src")
        [[ -n "$src" ]] || continue
        local filename key
        filename=$(basename "$src")
        [[ "$filename" == *.md ]] && filename="${filename%.md}"
        key=$(normalize_key "$filename")
        [[ -n "$key" ]] || { echo "Warning: unable to resolve agent name from '$src'; skipping."; continue; }
        desired["$key"]="$src"
    done

    [[ ${#desired[@]} -gt 0 ]] || die "no valid agent sources found."

    for cli in "${targets[@]}"; do
        local dest_dir
        dest_dir=$(agents_target_root "$cli") || continue
        mkdir -p "$dest_dir"

        declare -A current_keys=()
        while IFS= read -r agent; do
            [[ -n "$agent" ]] || continue
            current_keys["$(normalize_key "$agent")"]=1
        done < <(list_agents_in_dir "$dest_dir")

        for key in "${!desired[@]}"; do
            if [[ -z "${current_keys[$key]:-}" ]]; then
                echo "Installing $key for $cli..."
                if filename=$(download_agent "${desired[$key]}" "$dest_dir"); then
                    apply_agent_overrides "$dest_dir/$filename" "$cli"
                    echo "-> Installed $key to $dest_dir/$filename ($cli)"
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
    echo "Added: $url"
    echo "Run 'sync-ai.sh agents sync' to install."
}

agents_remove() {
    local name="${1:-}"
    [[ -n "$name" ]] || die "Agent name required"
    [[ -f "$AGENTS_CONF" ]] || die "Config not found: $AGENTS_CONF"

    local tmp
    tmp=$(mktemp)
    if grep -v "$name" "$AGENTS_CONF" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$AGENTS_CONF"
        echo "Removed: $name"
        echo "Run 'sync-ai.sh agents sync' to update CLIs."
    else
        rm -f "$tmp"
        die "Agent not found: $name"
    fi
}

agents_list() {
    if [[ ! -f "$AGENTS_CONF" ]]; then
        echo "No agents configured."
        return 0
    fi
    echo "Configured agents:"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(trim "$line")
        [[ -z "$line" || "$line" =~ ^# ]] && continue
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
  SKILLS_TARGETS    Comma-separated CLIs (default: codex,claude,opencode)
  AGENTS_CONFIG     Path to agents.conf (default: \$HOME/dotfiles/config/agents.conf)
  OPENCODE_CONFIG   Path to opencode.json
  CODEX_CONFIG      Path to codex config.toml
EOF
    exit 0
}

main() {
    case "${1:-sync}" in
        -h|--help) usage ;;
        sync)
            sync_skills
            sync_mcp
            sync_agents
            echo ""
            echo "Done. Restart Codex, Claude, and OpenCode to pick up changes."
            ;;
        skills)
            sync_skills
            ;;
        mcp)
            sync_mcp
            ;;
        agents)
            shift
            case "${1:-sync}" in
                sync)       sync_agents ;;
                add)        shift; agents_add "$@" ;;
                remove|rm)  shift; agents_remove "$@" ;;
                list|ls)    agents_list ;;
                *)          die "unknown agents command: $1" ;;
            esac
            ;;
        *)
            die "unknown command: $1"
            ;;
    esac
}

main "$@"
