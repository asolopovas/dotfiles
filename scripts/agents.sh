#!/usr/bin/env bash
set -euo pipefail

AGENTS_CONF="${AGENTS_CONFIG:-$HOME/dotfiles/config/agents.conf}"

AGENT_SOURCES=()

load_agent_sources() {
    if [[ -f "$AGENTS_CONF" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] && AGENT_SOURCES+=("$line")
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

    case "$cli" in
        opencode)
            sed -i '/^model:/d' "$file" 2>/dev/null || true
            ;;
    esac
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
        case "${cli,,}" in
            claude)
                if [[ -d "${CLAUDE_HOME:-$HOME/.claude}" ]] || have_cmd claude; then
                    resolved+=("claude")
                elif [[ -n "$raw" ]]; then
                    echo "Warning: claude not detected; skipping." >&2
                fi
                ;;
            codex)
                if [[ -d "${CODEX_HOME:-$HOME/.codex}" ]] || have_cmd codex; then
                    resolved+=("codex")
                elif [[ -n "$raw" ]]; then
                    echo "Warning: codex not detected; skipping." >&2
                fi
                ;;
            opencode)
                if [[ -d "${OPENCODE_HOME:-$HOME/.config/opencode}" ]] || have_cmd opencode; then
                    resolved+=("opencode")
                elif [[ -n "$raw" ]]; then
                    echo "Warning: opencode not detected; skipping." >&2
                fi
                ;;
            *)
                echo "Warning: unknown target '$cli'; skipping." >&2
                ;;
        esac
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

    if [[ "$target" == "opencode" ]]; then
        echo "-> Installed $name to $dest_dir/$filename (opencode)"
    elif [[ "$target" == "claude" ]]; then
        echo "-> Installed $name to $dest_dir/$filename (claude)"
    elif [[ "$target" == "codex" ]]; then
        echo "-> Installed $name to $dest_dir/$filename (codex - profile required)"
    fi
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

    echo "" >> "$agents_md"
    echo "## Custom Agents" >> "$agents_md"
    echo "" >> "$agents_md"

    for file in "$agents_dir"/*.md; do
        [[ -f "$file" ]] || continue
        local name
        name=$(resolve_agent_name "$file")
        if [[ -n "$name" ]]; then
            echo "### $name" >> "$agents_md"
            echo "" >> "$agents_md"
            cat "$file" >> "$agents_md"
            echo "" >> "$agents_md"
            echo "---" >> "$agents_md"
            echo "" >> "$agents_md"
        fi
    done
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
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" ]] && echo "  - $line"
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
                if [[ "$cli" == "opencode" ]]; then
                    echo "-> $key already installed (opencode)"
                elif [[ "$cli" == "claude" ]]; then
                    echo "-> $key already installed (claude)"
                elif [[ "$cli" == "codex" ]]; then
                    echo "-> $key already installed (codex)"
                fi
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

case "${1:-}" in
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
    "")
        sync_agents
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage
        exit 1
        ;;
esac
