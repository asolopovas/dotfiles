#!/usr/bin/env bash
set -euo pipefail

AGENTS_CONF="${AGENTS_CONFIG:-$HOME/dotfiles/config/agents.conf}"

AGENT_SOURCES=()

load_agent_sources() {
    if [[ -f "$AGENTS_CONF" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim "$line")
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            AGENT_SOURCES+=("$line")
        done < "$AGENTS_CONF"
    fi

    if [[ $# -gt 0 ]]; then
        AGENT_SOURCES+=("$@")
    fi
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  add <url>        Add an agent from URL
  remove <name>    Remove an agent by name
  list             List configured agents
  sync             Sync agents to all CLIs (default)

Options:
  -h, --help       Show this help

Environment:
  AGENTS_CONFIG    Path to config file (default: \$HOME/dotfiles/config/agents.conf)
  AGENTS_CLI       Comma-separated CLIs to sync to (default: claude,codex,opencode)

Examples:
  $(basename "$0") add https://github.com/.../agent.md
  $(basename "$0") remove code-simplifier
  $(basename "$0") list
  $(basename "$0") sync
EOF
    exit 0
}

die() {
    echo "$*" >&2
    exit 1
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

normalize_key() {
    local name="${1,,}"
    name="${name//[^a-z0-9]/-}"
    echo "$name"
}

apply_cli_overrides() {
    local file="$1"
    local cli="$2"

    if [[ "$cli" == "opencode" ]] && [[ -f "$file" ]]; then
        sed -i '/^model:/d' "$file" 2>/dev/null || true
    fi
}

resolve_agent_name() {
    local file="$1"
    local name

    if [[ -f "$file" ]]; then
        name=$(sed -n '/^---$/,/^---$/s/^name: *//p' "$file" 2>/dev/null | head -1)
    fi

    if [[ -z "$name" ]]; then
        name=$(basename "$file" .md | sed 's/\.md$//')
    fi

    name=$(normalize_key "$name")
    printf '%s' "$name"
}

resolve_clis() {
    local raw="${AGENTS_CLI:-}"
    local -a candidates=()
    local -a resolved=()

    if [[ -n "$raw" ]]; then
        raw="${raw//,/ }"
        read -ra candidates <<< "$raw"
    else
        candidates=(claude codex opencode)
    fi

    for cli in "${candidates[@]}"; do
        [[ -n "$cli" ]] || continue
        cli_lower="${cli,,}"

        local detected=false
        local home_var=""

        case "$cli_lower" in
            claude)
                detected=true
                home_var="CLAUDE_HOME"
                ;;
            codex)
                detected=true
                home_var="CODEX_HOME"
                ;;
            opencode)
                detected=true
                home_var="OPENCODE_HOME"
                ;;
            *)
                echo "Warning: unknown target '$cli'; skipping." >&2
                continue
                ;;
        esac

        if [[ "$detected" == "true" ]]; then
            local home_val="${!home_var:-}"
            local home_path="${home_val:-$HOME}"

            case "$cli_lower" in
                claude)  home_path="$home_path/.claude" ;;
                codex)   home_path="$home_path/.codex" ;;
                opencode) home_path="$home_path/.config/opencode" ;;
            esac

            if [[ -d "$home_path" ]] || have_cmd "$cli_lower"; then
                resolved+=("$cli_lower")
            elif [[ -n "$raw" ]]; then
                echo "Warning: $cli not detected; skipping." >&2
            fi
        fi
    done

    if [[ ${#resolved[@]} -eq 0 ]]; then
        die "Error: no supported CLI detected (codex, claude, opencode)."
    fi

    printf '%s\n' "${resolved[@]}"
}

target_root() {
    case "$1" in
        claude) echo "${CLAUDE_HOME:-$HOME/.claude}/agents" ;;
        codex) echo "${CODEX_HOME:-$HOME/.codex}/agents" ;;
        opencode) echo "${OPENCODE_HOME:-$HOME/.config/opencode}/agent" ;;
        *) return 1 ;;
    esac
}

download_agent() {
    local url="$1"
    local dest_dir="$2"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local filename

    trap "rm -rf '$tmp_dir'" EXIT

    if ! curl -fsSLo "$tmp_dir/downloaded" "$url" 2>/dev/null; then
        echo "Failed to download: $url" >&2
        return 1
    fi

    filename=$(basename "$url")
    if [[ "$filename" != *.md ]]; then
        filename="${filename}.md"
    fi

    mv "$tmp_dir/downloaded" "$dest_dir/$filename"
    printf '%s' "$filename"
}

install_agent() {
    local target="$1"
    local dest_dir="$2"
    local url="$3"
    local filename

    mkdir -p "$dest_dir"

    if ! filename=$(download_agent "$url" "$dest_dir"); then
        return 1
    fi

    apply_cli_overrides "$dest_dir/$filename" "$target"

    local name
    name=$(resolve_agent_name "$dest_dir/$filename")

    local suffix=""
    case "$target" in
        codex) suffix="(codex - profile required)" ;;
        *)     suffix="($target)" ;;
    esac

    echo "-> Installed $name to $dest_dir/$filename $suffix"
}

list_agents() {
    local target="$1"
    local dest_dir="$2"

    if [[ ! -d "$dest_dir" ]]; then
        return
    fi

    for file in "$dest_dir"/*.md; do
        [[ -f "$file" ]] || continue
        local name
        name=$(resolve_agent_name "$file")
        [[ -n "$name" ]] && echo "$name"
    done
}

sync_codex_agents() {
    local codex_home="${CODEX_HOME:-$HOME/.codex}"
    local agents_dir="$codex_home/agents"
    local agents_md="$codex_home/AGENTS.md"

    if [[ ! -d "$agents_dir" ]]; then
        return 0
    fi

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

add_agent() {
    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Error: URL required" >&2
        exit 1
    fi

    if [[ ! -f "$AGENTS_CONF" ]]; then
        mkdir -p "$(dirname "$AGENTS_CONF")"
        echo "# Agent configuration file" > "$AGENTS_CONF"
        echo "# Add agent URLs below, one per line" >> "$AGENTS_CONF"
        echo "" >> "$AGENTS_CONF"
    fi

    if grep -qF "$url" "$AGENTS_CONF" 2>/dev/null; then
        echo "Agent already exists in $AGENTS_CONF"
        exit 0
    fi

    echo "$url" >> "$AGENTS_CONF"
    echo "Added: $url"
    echo ""
    echo "Run '$(basename "$0") sync' to install to CLIs"
}

remove_agent() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Error: Agent name required" >&2
        exit 1
    fi

    if [[ ! -f "$AGENTS_CONF" ]]; then
        echo "Config file not found: $AGENTS_CONF"
        exit 1
    fi

    local temp_file
    temp_file=$(mktemp)

    if grep -qv "$name" "$AGENTS_CONF" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$AGENTS_CONF"
        echo "Removed: $name"
        echo ""
        echo "Run '$(basename "$0") sync' to update CLIs"
    else
        rm "$temp_file"
        echo "Agent not found: $name"
        exit 1
    fi
}

list_agents_config() {
    if [[ ! -f "$AGENTS_CONF" ]]; then
        echo "No agents configured"
        exit 0
    fi

    echo "Configured agents:"
    echo ""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(trim "$line")
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        echo "  - $line"
    done < "$AGENTS_CONF"
}

sync_agents() {
    load_agent_sources "$@"

    if [[ ${#AGENT_SOURCES[@]} -eq 0 ]]; then
        echo "No agent sources found. Add URLs to AGENTS_CONFIG or pass as arguments."
        exit 0
    fi

    mapfile -t CLIS < <(resolve_clis)

    declare -A DESIRED_URL=()
    for source in "${AGENT_SOURCES[@]}"; do
        source=$(trim "$source")
        if [[ -z "$source" ]]; then
            continue
        fi

        filename=$(basename "$source")
        if [[ "$filename" == *.md ]]; then
            filename="${filename%.md}"
        fi
        key=$(normalize_key "$filename")

        if [[ -z "$key" ]]; then
            echo "Warning: unable to resolve agent name from '$source'; skipping."
            continue
        fi

        DESIRED_URL["$key"]="$source"
    done

    if [[ ${#DESIRED_URL[@]} -eq 0 ]]; then
        die "Error: no valid agent sources found."
    fi

    for cli in "${CLIS[@]}"; do
        dest_dir=$(target_root "$cli") || continue
        mkdir -p "$dest_dir"

        declare -A current_keys=()

        while IFS= read -r agent; do
            [[ -n "$agent" ]] || continue
            key=$(normalize_key "$agent")
            if [[ -n "$key" ]]; then
                current_keys["$key"]=1
            fi
        done < <(list_agents "$cli" "$dest_dir")

        for key in "${!DESIRED_URL[@]}"; do
            if [[ -z "${current_keys[$key]:-}" ]]; then
                echo "Installing $key for $cli..."
                if ! install_agent "$cli" "$dest_dir" "${DESIRED_URL[$key]}"; then
                    echo "Warning: failed to install $key for $cli" >&2
                fi
            else
                local suffix=""
                case "$cli" in
                    codex) suffix=" (codex)" ;;
                    *)     suffix=" ($cli)" ;;
                esac
                echo "-> $key already installed$suffix"
                apply_cli_overrides "$dest_dir/${key}.md" "$cli"
            fi
        done

        if [[ "$cli" == "codex" ]]; then
            echo "Note: Codex requires profile-based usage. Run: codex exec --profile <agent-name>"
            echo "      Or create profiles in ~/.codex/config.toml"
        fi
    done

    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        printf "%s\n" "$(tput setaf 2)✅ Agent sync complete$(tput sgr0)"
    else
        echo "✅ Agent sync complete"
    fi
}

case "${1:-sync}" in
    -h|--help)
        usage
        ;;
    add)
        shift
        add_agent "$@"
        ;;
    remove|rm|delete)
        shift
        remove_agent "$@"
        ;;
    list|ls)
        shift
        list_agents_config
        ;;
    sync)
        shift
        sync_agents "$@"
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage
        exit 1
        ;;
esac
