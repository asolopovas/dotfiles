#!/usr/bin/env bats

H="/home/stduser"
D="$H/dotfiles"

@test "stduser: dotfiles and globals are ready" {
    [ -d "$D/.git" ]
    [ -f "$D/init.sh" ]
    run sudo -u stduser bash -c "source $D/globals.sh"
    [ "$status" -eq 0 ]
}

@test "stduser: base directories and symlinks exist" {
    for path in "$H/.config" "$H/.local/bin" "$H/.tmp" "$H/src" "$H/.cache"; do
        [ -d "$path" ]
    done
    for path in "$H/.bashrc" "$H/.gitconfig" "$H/.gitignore" "$H/.config/fish" "$H/.config/tmux" "$H/.config/nvim" "$H/.local/bin/helpers"; do
        [ -L "$path" ]
    done
    [[ "$(readlink "$H/.bashrc")" == */dotfiles/.bashrc ]]
    [[ "$(readlink "$H/.config/nvim")" == */dotfiles/.config/nvim ]]
}

@test "stduser: core tools are installed" {
    [ -x "$H/.local/bin/composer" ]
    [ -x "$H/.bun/bin/bun" ]
    [ -x "$H/.deno/bin/deno" ]
    [ -x "$H/.local/bin/fd" ]
    [ -x "$H/.local/bin/fzf" ]
    [ -x "$H/.volta/bin/volta" ]
    [ -x "$H/.local/nvim/bin/nvim" ]
    [ -d "$H/.local/share/omf" ]
}

@test "stduser: installed tools run" {
    run sudo -u stduser "$H/.bun/bin/bun" --version
    [ "$status" -eq 0 ]
    run sudo -u stduser "$H/.deno/bin/deno" --version
    [ "$status" -eq 0 ]
    run sudo -u stduser "$H/.local/bin/fd" --version
    [ "$status" -eq 0 ]
    run sudo -u stduser "$H/.local/bin/fzf" --version
    [ "$status" -eq 0 ]
    run sudo -u stduser env HOME="$H" PATH="$H/.volta/bin:$PATH" volta run node --version
    [ "$status" -eq 0 ]
    [[ "$output" == v* ]]
    run sudo -u stduser "$H/.local/nvim/bin/nvim" --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"NVIM"* ]]
}

@test "stduser: bootstrap is idempotent" {
    local hidden=0
    if [ -d /etc/psa ]; then
        sudo mv /etc/psa /etc/psa.hidden
        hidden=1
    fi
    run sudo -u stduser env HOME="$H" CHANGE_SHELL=false bash "$D/init.sh"
    if [ "$hidden" -eq 1 ]; then
        sudo mv /etc/psa.hidden /etc/psa
    fi
    [ "$status" -eq 0 ]
}
