#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-browser-open.sh [--mode cmd|chrome-debug] [--chrome-debug PATH] [--cmd PATH] [--home PATH]

Installs ~/.local/bin/browser-open and sets BROWSER in ~/.env-vars.

Options:
  --mode          cmd (default) or chrome-debug
  --chrome-debug  path to chrome-debug.sh (default: ~/dotfiles/scripts/chrome-debug.sh)
  --cmd           path to cmd.exe (default: /mnt/c/Windows/System32/cmd.exe)
  --home          override home directory (default: $HOME)
  -h, --help      show help
EOF
}

home_dir="${HOME}"
mode="chrome-debug"
chrome_debug_path=""
cmd_path="/mnt/c/Windows/System32/cmd.exe"

while [ $# -gt 0 ]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --chrome-debug) chrome_debug_path="${2:-}"; shift 2 ;;
    --cmd) cmd_path="${2:-}"; shift 2 ;;
    --home) home_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$mode" in
  cmd|chrome-debug) ;;
  *) echo "Invalid --mode: $mode (expected cmd|chrome-debug)" >&2; exit 2 ;;
esac

if [ -z "$chrome_debug_path" ]; then
  chrome_debug_path="${home_dir}/dotfiles/scripts/chrome-debug.sh"
fi

bin_dir="${home_dir}/.local/bin"
browser_script="${bin_dir}/browser-open"
env_file="${home_dir}/.env-vars"

mkdir -p "$bin_dir"

if [ "$mode" = "cmd" ]; then
  cat > "$browser_script" <<EOF
#!/bin/bash
set -euo pipefail
cd /mnt/c
exec "$cmd_path" /c start "\$1"
EOF
else
  cat > "$browser_script" <<EOF
#!/bin/bash
set -euo pipefail
exec "$chrome_debug_path" "\${1:-}"
EOF
fi

chmod +x "$browser_script"

if [ -f "$env_file" ]; then
  sed -i '/^BROWSER=/d' "$env_file"
  printf "BROWSER='%s'\n" "$browser_script" >> "$env_file"
  echo "Added BROWSER setting to $env_file"
else
  printf "BROWSER='%s'\n" "$browser_script" > "$env_file"
  echo "Created $env_file with BROWSER setting"
fi

echo "Installed: $browser_script (mode: $mode)"
echo "Restart your shell or run: source '$env_file'"
