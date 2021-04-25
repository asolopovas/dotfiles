#!/bin/bash
OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')

command_exists() {
  command -v $1 >/dev/null 2>&1
}

is_sudoer() {
  sudo -v > /dev/null 2>&1
}

removePackage() {
  printf "\n************************************************\n"
  printf "Removing $1 package from the system\n"
  printf "\n************************************************\n"
  if command_exists $1 && is_sudoer; then
    echo $OS
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
  printf "\n************************************************\n"
  printf "Installing $1 package\n"
  printf "\n************************************************\n"
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

printf "Installing dotfiles...\n"
while true; do
  read -p "Use https origin for dotfiles? (default: https) [yes/no]" yn
  case $yn in
    [Nn]*)
      dotfiles_origin=git@github.com:asolopovas/dotfiles.git
      git clone $dotfiles_origin
      break;;
    *)
      dotfiles_origin=https://github.com/asolopovas/dotfiles.git
      git clone $dotfiles_origin
      break;;
  esac
done


# -------------------------------------
# Install zsh
# -------------------------------------
while true; do
  read -p "Install Zsh? (default: no) [yes/no]" yn
  case $yn in
    [Yy]*)
      installPackage zsh
      default_shell=$(which zsh)
      oh_my_plugin="https://github.com/ohmyzsh/ohmyzsh.git"
      oh_my_name=$(basename $oh_my_plugin | sed 's/\.[^.]*$//')
      ln -sf "$HOME/.config/zsh/.zshrc" "$HOME/.zshrc"
      if [ ! -d "$HOME/.config/$oh_my_name" ]; then
        git clone $oh_my_plugin "$HOME/.config/$oh_my_name"
      fi
      break;;
    *)
      break;;
  esac
done

# -------------------------------------
# Install Fish
# -------------------------------------
while true; do
  read -p "Install Fish Shell? (default: no) [yes/no]" yn
  case $yn in
    [Yy]*)
      installPackage fish
      curl -L https://get.oh-my.fish > install
      fish install --offline=omf.tar.gz
      default_shell=$(which fish)
      break;;
    *)
      break;;
  esac
done

# -------------------------------------
# Install Neovim
# -------------------------------------
while true; do
  read -p "Install NeoVim? (default: no) [yes/no]" yn
  case $yn in
    [Yy]*)
      removePackage vim
      vim_plug_autoload=~/.config/nvim/autoload/plug.vim
      vim_plug=https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
      if [ ! -f $vim_plug_autoload ]; then
        curl -fLo $vim_plug_autoload --create-dirs $vim_plug
      fi
      installPackage neovim
      nvim +silent +PlugInstall +qall
      break;;
    *)
      break;;
  esac
done

# -------------------------------------
# Install fuzzy search
# -------------------------------------
while true; do
  read -p "Install fuzzy search for terminal? (default: no) [yes/no]" yn
  case $yn in
    [Yy]*)
      installPackage ripgrep
      installPackage fzf
      if [ "$OS" == "ubuntu" ]; then
        installPackage fd-find
        sudo ln -sf /usr/bin/fdfind /usr/bin/fd
      fi
      printf "Installing Fuzzy Search...\n"
      mkdir -p ~/.local/share/gem/bin
      git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/fzf
      ~/.config/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
      mv ~/.fzf.zsh ~/.config/fzf.zsh
        break;;
    *)
      break;;
  esac
done

source $HOME/dotfiles/dotfiles-sync.sh
