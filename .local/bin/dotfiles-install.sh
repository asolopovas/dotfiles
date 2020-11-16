#!/bin/bash
OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')

command_exists() {
	command -v $1 >/dev/null 2>&1
}

is_sudoer() {
  sudo -v > /dev/null 2>&1
}

removePackage() {
  if ! command_exists $1 && is_sudoer; then
    case $OS in
      ubuntu)
        sudo apt remove -y $1;
        ;;
      centos)
        sudo yum remove -y $1;
        ;;
      arch)
        sudo pacman -Rns --noconfirm $1;
        ;;
    esac
  fi
}

installPackage() {
  if ! command_exists $1 && is_sudoer; then
    case $OS in
      ubuntu)
        sudo apt install -y $1;
        ;;
      centos)
        sudo yum install -y $1;
        ;;
      arch)
        sudo pacman -S --noconfirm $1;
        ;;
    esac
  fi
}

cd $HOME
# -------------------------------------
# Download and install dotfiles
# -------------------------------------
mkdir $HOME/.cache 2> /dev/null && touch $HOME/.cache/.zsh_history
git_origin=$(git remote get-url origin) 2> /dev/null

printf "Installing dotfiles...\n"
while true; do
  read -p "Use https origin for dotfiles? (default: https) [yes/no]" yn
  case $yn in
    [Nn]*)
      dotfiles_origin=git@github.com:asolopovas/dotfiles.git
      break;;
    *)
      dotfiles_origin=https://github.com/asolopovas/dotfiles.git
      break;;
  esac
done

if [ ! -d "$HOME/.git" ]; then
  cd $HOME
  git init
  git remote add origin $dotfiles_origin
  git fetch origin
  git reset --hard origin/master
  git branch --set-upstream-to=origin/master master
  cd -
fi

# -------------------------------------
# Install zsh
# -------------------------------------
installPackage zsh
default_shell=$(which zsh)
oh_my_plugin="https://github.com/ohmyzsh/ohmyzsh.git"
oh_my_name=$(basename $oh_my_plugin | sed 's/\.[^.]*$//')

if [ ! -d "$HOME/.config/$oh_my_name" ]; then
  git clone $oh_my_plugin "$HOME/.config/$oh_my_name"
fi

if is_sudoer; then
  chsh -s $default_shell
fi


# -------------------------------------
# Install nvim
# -------------------------------------
nvim_home_autoload=~/.config/nvim/autoload/plug.vim
nvim_root_autoload=/usr/share/nvim/runtime/autoload/plug.vim
nvim_plug_url=https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
if [ ! -f $nvim_home_autoload ]; then
  curl -fLo $nvim_home_autoload --create-dirs $nvim_plug_url
fi

removePackage vim
installPackage neovim

nvim +silent +PlugInstall +qall;

# -------------------------------------
# Install fuzzy search
# -------------------------------------
installPackage ripgrep
printf "Installing Fuzzy Search...\n"
mkdir -p ~/.local/share/gem/bin
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/fzf
~/.config/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
mv ~/.fzf.zsh ~/.config/fzf.zsh

# -------------------------------------
# Start zsh
# -------------------------------------
ln -sf "$HOME/.config/zsh/.zshrc" "$HOME/.zshrc"
zsh
