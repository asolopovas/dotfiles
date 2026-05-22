#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_AGENTS_DIR="${DOTFILES_AGENTS_DIR:-$DOTFILES_DIR/.agents}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.agents}"
WINDOWS_AGENTS_DIR="${WINDOWS_AGENTS_DIR:-}"

CONFIG_LINKS=(
	".claude/settings.json"
	".config/opencode/opencode.jsonc"
	".pi/agent/settings.json"
	".pi/agent/npm/package.json"
)

CONFIG_DIRS=(
	".pi/agent/prompts"
)

SKILL_LINKS=(
	".claude/skills"
	".codex/skills"
)

die() {
	echo "Error: $*" >&2
	exit 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

is_wsl() {
	[[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
	[[ -r /proc/version ]] && grep -qi microsoft /proc/version
}

ensure_parent() {
	mkdir -p "$(dirname "$1")"
}

backup_path() {
	local path="$1" backup
	backup="$path.backup.$(date +%Y%m%d%H%M%S)"

	while [[ -e "$backup" || -L "$backup" ]]; do
		backup="$path.backup.$(date +%Y%m%d%H%M%S).$$"
	done

	mv "$path" "$backup"
	echo "-> backup: $path -> $backup"
}

replace_with_symlink() {
	local src="$1" dst="$2"

	[[ -e "$src" ]] || die "source does not exist: $src"

	if [[ -L "$dst" ]]; then
		[[ "$(readlink "$dst")" == "$src" ]] && return 0
		rm -f "$dst"
	elif [[ -e "$dst" ]]; then
		if [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
			rmdir "$dst"
		else
			die "$dst exists and is not an empty directory or symlink"
		fi
	fi

	ensure_parent "$dst"
	ln -s "$src" "$dst"
	echo "-> symlink: $dst -> $src"
}

replace_config_with_symlink() {
	local src="$1" dst="$2"

	[[ -e "$src" ]] || die "source does not exist: $src"

	if [[ -L "$dst" ]]; then
		[[ "$(readlink "$dst")" == "$src" ]] && return 0
		rm -f "$dst"
	elif [[ -e "$dst" ]]; then
		if [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
			rmdir "$dst"
		elif [[ -f "$dst" ]]; then
			if cmp -s "$src" "$dst"; then
				rm -f "$dst"
			else
				backup_path "$dst"
			fi
		else
			die "$dst exists and cannot be replaced safely"
		fi
	fi

	ensure_parent "$dst"
	ln -s "$src" "$dst"
	echo "-> symlink: $dst -> $src"
}

sync_config_file() {
	local src="$1" dst="$2"

	[[ -e "$src" ]] || die "source does not exist: $src"

	if [[ -L "$dst" || -e "$dst" ]]; then
		if [[ -f "$dst" || -L "$dst" ]]; then
			cmp -s "$src" "$dst" && return 0
			backup_path "$dst"
		elif [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
			rmdir "$dst"
		else
			die "$dst exists and cannot be replaced safely"
		fi
	fi

	ensure_parent "$dst"
	cp "$src" "$dst"
	echo "-> copy: $src -> $dst"
}

sync_directory() {
	local src="$1" dst="$2" parent

	[[ -d "$src" ]] || die "source does not exist: $src"
	parent="$(dirname "$dst")"

	if have_cmd rsync; then
		mkdir -p "$dst"
		rsync -a --delete "$src/" "$dst/"
	else
		rm -rf "$dst"
		mkdir -p "$parent"
		cp -a "$src" "$dst"
	fi
	echo "-> synced directory: $src -> $dst"
}

sync_linux_npm_packages() {
	local prefix="$HOME/.pi/agent/npm"

	[[ -d "$prefix/node_modules" ]] || return 0
	have_cmd npm || return 0
	npm install --prefix "$prefix"
}

sync_linux_pi_packages() {
	local prefix="$HOME/.pi/agent"

	[[ -d "$prefix/npm/node_modules" || -d "$prefix/git" ]] || return 0
	have_cmd pi || return 0
	pi update --extensions
}

sync_windows_npm_packages() {
	is_wsl || return 0
	have_cmd powershell.exe || return 0
	have_cmd wslpath || return 0

	local home_dir prefix win_prefix
	home_dir=$(windows_home_dir) || return 0
	prefix="$home_dir/.pi/agent/npm"
	[[ -d "$prefix/node_modules" ]] || return 0
	win_prefix=$(wslpath -w "$prefix")
	powershell.exe -NoProfile -Command "Set-Location -LiteralPath \$env:TEMP; & npm.cmd install --prefix '$win_prefix'" | tr -d '\r'
}

sync_windows_pi_packages() {
	is_wsl || return 0
	have_cmd powershell.exe || return 0
	have_cmd wslpath || return 0

	local home_dir prefix win_home
	home_dir=$(windows_home_dir) || return 0
	prefix="$home_dir/.pi/agent"
	[[ -d "$prefix/npm/node_modules" || -d "$prefix/git" ]] || return 0
	win_home=$(wslpath -w "$home_dir")
	powershell.exe -NoProfile -Command "Set-Location -LiteralPath '$win_home'; if (Get-Command pi.cmd -ErrorAction SilentlyContinue) { & pi.cmd update --extensions } elseif (Get-Command pi -ErrorAction SilentlyContinue) { & pi update --extensions }" | tr -d '\r'
}

sync_linux_agents() {
	replace_with_symlink "$DOTFILES_AGENTS_DIR" "$AGENTS_DIR"

	local relpath
	for relpath in "${SKILL_LINKS[@]}"; do
		replace_with_symlink "$AGENTS_DIR/skills" "$HOME/$relpath"
	done
}

sync_linux_configs() {
	local relpath src
	for relpath in "${CONFIG_LINKS[@]}"; do
		src="$DOTFILES_DIR/$relpath"
		[[ -e "$src" ]] || continue
		replace_config_with_symlink "$src" "$HOME/$relpath"
	done

	for relpath in "${CONFIG_DIRS[@]}"; do
		src="$DOTFILES_DIR/$relpath"
		[[ -d "$src" ]] || continue
		replace_with_symlink "$src" "$HOME/$relpath"
	done
}

windows_home_dir() {
	if [[ -n "${WINDOWS_AGENTS_DIR:-}" ]]; then
		dirname "$WINDOWS_AGENTS_DIR"
		return 0
	fi

	if have_cmd powershell.exe && have_cmd wslpath; then
		local win_home
		win_home=$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("UserProfile")' 2>/dev/null | tr -d '\r' | tail -n 1)
		[[ -n "$win_home" ]] && wslpath -u "$win_home" && return 0
	fi

	if [[ -d /mnt/c/Users ]]; then
		local dir name
		for dir in /mnt/c/Users/*; do
			[[ -d "$dir" ]] || continue
			name="$(basename "$dir")"
			case "${name,,}" in
			default | defaultuser0 | public | all\ users | desktop.ini) continue ;;
			esac
			printf '%s\n' "$dir"
			return 0
		done
	fi

	return 1
}

windows_agents_dir() {
	if [[ -n "${WINDOWS_AGENTS_DIR:-}" ]]; then
		printf '%s\n' "$WINDOWS_AGENTS_DIR"
		return 0
	fi

	local home_dir
	home_dir=$(windows_home_dir) || return 1
	printf '%s\n' "$home_dir/.agents"
}

sync_windows_agents() {
	is_wsl || return 0

	local dst parent
	dst=$(windows_agents_dir) || return 0
	parent="$(dirname "$dst")"
	[[ -d "$parent" ]] || return 0

	sync_directory "$DOTFILES_AGENTS_DIR" "$dst"
}

sync_windows_configs() {
	is_wsl || return 0

	local home_dir relpath src
	home_dir=$(windows_home_dir) || return 0
	[[ -d "$home_dir" ]] || return 0

	for relpath in "${CONFIG_LINKS[@]}"; do
		src="$DOTFILES_DIR/$relpath"
		[[ -e "$src" ]] || continue
		sync_config_file "$src" "$home_dir/$relpath"
	done

	for relpath in "${CONFIG_DIRS[@]}"; do
		src="$DOTFILES_DIR/$relpath"
		[[ -d "$src" ]] || continue
		sync_directory "$src" "$home_dir/$relpath"
	done
}

sync_all() {
	[[ -d "$DOTFILES_AGENTS_DIR" ]] || die "missing dotfiles agents directory: $DOTFILES_AGENTS_DIR"
	sync_linux_agents
	sync_linux_configs
	sync_linux_npm_packages
	sync_linux_pi_packages
	sync_windows_agents
	sync_windows_configs
	sync_windows_npm_packages
	sync_windows_pi_packages
	echo "Done. Restart Codex, Claude, and OpenCode to pick up changes."
}

usage() {
	cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  sync              Sync agents and config links (default)
  config            Sync config links only
  agents            Sync ~/.agents and CLI skill links only
  windows           Sync .agents, Pi prompts, configs, and Pi npm packages to Windows from WSL only

Options:
  -h, --help        Show this help

Environment:
  DOTFILES_DIR      Dotfiles checkout (default: \$HOME/dotfiles)
  AGENTS_DIR        Linux agents path (default: \$HOME/.agents)
  WINDOWS_AGENTS_DIR Windows agents path override (default: detected Windows user profile + /.agents)
EOF
}

main() {
	case "${1:-sync}" in
	-h | --help) usage ;;
	sync) sync_all ;;
	config) sync_linux_configs ;;
	agents) sync_linux_agents ;;
	windows)
		sync_windows_agents
		sync_windows_configs
		sync_windows_npm_packages
		sync_windows_pi_packages
		;;
	*) die "unknown command: $1" ;;
	esac
}

main "$@"
