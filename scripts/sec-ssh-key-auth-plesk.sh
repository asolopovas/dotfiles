#!/usr/bin/env bash
# sec-ssh-key-auth-plesk.sh
#
# Deploy SSH public key to all Plesk virtual hosting users

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_NAME="$(basename "$0")"

# ============================================================================
# Functions
# ============================================================================

show_help() {
    cat <<HELP
Deploy SSH public key to all Plesk virtual hosting users.

Usage:
    $SCRIPT_NAME [OPTIONS] <public_key_file|public_key_string>

Arguments:
    public_key_file      Path to SSH public key file
    public_key_string    Raw SSH public key string

Options:
    -f, --force         Overwrite existing authorized_keys instead of appending
    -n, --dry-run       Show what would be done without making changes
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

Prerequisites:
    - SSH access configured for 'root' alias in ~/.ssh/config
    - Root privileges on the Plesk server

Example:
    $SCRIPT_NAME ~/.ssh/id_rsa.pub
    $SCRIPT_NAME -f ~/.ssh/id_ed25519.pub
    $SCRIPT_NAME --dry-run "ssh-rsa AAAAB3Nza... user@host"

HELP
    exit 0
}

validate_ssh_key_format() {
    local key_content="$1"
    
    # Validate SSH key format (supports common key types)
    if ! echo "$key_content" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521)|ssh-dss) '; then
        echo "❌ Error: Invalid SSH public key format" >&2
        echo "   Supported formats: ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp*, ssh-dss" >&2
        exit 1
    fi
    
    [[ "$VERBOSE" -eq 1 ]] && echo "✓ Valid SSH public key format detected"
}

get_and_validate_key() {
    local input="$1"
    local key_content
    
    # Check if input is a file path
    if [[ -f "$input" ]]; then
        [[ "$VERBOSE" -eq 1 ]] && echo "✓ Detected file path: $input"
        
        if [[ ! -r "$input" ]]; then
            echo "❌ Error: Cannot read public key file: $input" >&2
            exit 1
        fi
        
        # Read and trim the key from file
        key_content="$(<"$input")"
        key_content="$(echo -n "$key_content" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    else
        # Treat as raw key string
        [[ "$VERBOSE" -eq 1 ]] && echo "✓ Detected raw SSH key string"
        key_content="$(echo -n "$input" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    fi
    
    # Validate the key format
    validate_ssh_key_format "$key_content"
    
    echo "$key_content"
}

prepare_key() {
    local public_key="$1"
    
    # Base64-encode into a single line for safe transmission over SSH
    local public_key_b64
    public_key_b64="$(
        echo -n "$public_key" |
            base64 |
            tr -d '\n'
    )"
    
    [[ "$VERBOSE" -eq 1 ]] && echo "✓ Key prepared for transmission"
    
    echo "$public_key_b64"
}

deploy_to_plesk() {
    local force="$1"
    local dry_run="$2"
    local verbose="$3"
    local public_key_b64="$4"
    
    if [[ "$dry_run" -eq 1 ]]; then
        echo "🔍 Dry-run mode: Connecting to root to preview changes..."
    else
        echo "🔄 Connecting to root to update authorized_keys for Plesk users..."
    fi
    
    # Execute remote commands on Plesk server
    # The 'root' alias should be configured in ~/.ssh/config
    ssh root bash -s -- "$force" "$dry_run" "$verbose" "$public_key_b64" <<'EOF'
force="$1"
dry_run="$2"
verbose="$3"
public_key_b64="$4"

# Decode the base64-encoded key
public_key="$(echo "$public_key_b64" | base64 -d)"

# Query Plesk database to get all virtual hosting domains
# Retrieves: domain name, system user login, and home directory
plesk_users="$(
  plesk db -N -B -e "
    SELECT d.name, s.login, s.home
    FROM domains d
    JOIN hosting h ON d.id = h.dom_id
    JOIN sys_users s ON h.sys_user_id = s.id
    WHERE d.htype = 'vrt_hst'
  "
)"

user_count=0
updated_count=0
skipped_count=0

while IFS=$'\t' read -r domain plesk_user home_dir; do
    # Skip invalid entries
    [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && continue
    id "$plesk_user" &>/dev/null || continue
    [ -d "$home_dir" ] || continue

    user_count=$((user_count + 1))
    ssh_dir="$home_dir/.ssh"
    authorized_keys="$ssh_dir/authorized_keys"

    if [[ "$verbose" -eq 1 ]]; then
        echo "Processing: $plesk_user ($domain) -> $home_dir"
    fi

    # Dry-run: just report what would be done
    if [[ "$dry_run" -eq 1 ]]; then
        if [ "$force" -eq 1 ]; then
            echo "  [DRY-RUN] Would overwrite authorized_keys for: $plesk_user ($domain)"
        else
            if [ -f "$authorized_keys" ] && grep -qxF "$public_key" "$authorized_keys"; then
                echo "  [DRY-RUN] Key already present for: $plesk_user ($domain)"
            else
                echo "  [DRY-RUN] Would append key to: $plesk_user ($domain)"
            fi
        fi
        continue
    fi

    # Create .ssh directory if it doesn't exist
    if [ ! -d "$ssh_dir" ]; then
        echo "📂 Creating .ssh directory for user: $plesk_user ($domain)"
        mkdir -p "$ssh_dir"
        chown "$plesk_user":"$plesk_user" "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi

    if [ "$force" -eq 1 ]; then
        # Force mode: overwrite authorized_keys
        echo "$public_key" > "$authorized_keys"
        echo "✅ Overwritten authorized_keys for user: $plesk_user ($domain)"
        updated_count=$((updated_count + 1))
    else
        # Append mode: only add if key is not already present
        if [ -f "$authorized_keys" ] && grep -qxF "$public_key" "$authorized_keys"; then
            echo "ℹ️  Key already present for user: $plesk_user ($domain). Skipping."
            skipped_count=$((skipped_count + 1))
        else
            echo "$public_key" >> "$authorized_keys"
            echo "✅ Appended public key for user: $plesk_user ($domain)"
            updated_count=$((updated_count + 1))
        fi
    fi

    # Set correct permissions
    chmod 600 "$authorized_keys"
    chown "$plesk_user":psacln "$authorized_keys"

done <<< "$plesk_users"

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$dry_run" -eq 1 ]]; then
    echo "Dry-run Summary: Found $user_count Plesk user(s)"
else
    echo "Summary: Processed $user_count user(s)"
    echo "  Updated: $updated_count"
    echo "  Skipped: $skipped_count"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EOF
}

# ============================================================================
# Main Script
# ============================================================================

# Parse command-line arguments
FORCE=0
DRY_RUN=0
VERBOSE=0
PUBLIC_KEY_INPUT=""

# Show help if no arguments
if [[ $# -eq 0 ]]; then
    show_help
fi

# Parse options using manual loop to support both short and long options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -*)
            echo "❌ Error: Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
        *)
            if [[ -z "$PUBLIC_KEY_INPUT" ]]; then
                PUBLIC_KEY_INPUT="$1"
                shift
            else
                echo "❌ Error: Unexpected argument: $1" >&2
                echo "Use -h or --help for usage information" >&2
                exit 1
            fi
            ;;
    esac
done

# Validate that a key file or string was provided
if [[ -z "$PUBLIC_KEY_INPUT" ]]; then
    echo "❌ Error: Public key file or string is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# Main execution flow
[[ "$VERBOSE" -eq 1 ]] && echo "🔑 Validating SSH key input..."
PUBLIC_KEY="$(get_and_validate_key "$PUBLIC_KEY_INPUT")"

[[ "$VERBOSE" -eq 1 ]] && echo "🔧 Preparing key for deployment"
PUBLIC_KEY_B64="$(prepare_key "$PUBLIC_KEY")"

deploy_to_plesk "$FORCE" "$DRY_RUN" "$VERBOSE" "$PUBLIC_KEY_B64"

if [[ "$DRY_RUN" -eq 0 ]]; then
    echo "✅ Finished updating authorized_keys for Plesk users!"
fi