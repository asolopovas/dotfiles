#!/bin/bash

function syncConfig {
  srcPath=$1
  destPath=$2

  dotfiles=()

  while IFS=  read -r -d $'\0'; do
    dotfiles+=($REPLY)
  done < <(find $srcPath -maxdepth 1 -print0)

  for src in "${dotfiles[@]}"
  do
    if [  $srcPath == $src ]; then continue; fi
    dest=${src/\/dotfiles\///}
    rm -rf $dest
    ln -sf $src $destPath
  done

}

syncConfig ~/dotfiles/.config ~/.config
syncConfig ~/dotfiles/.local ~/.local

# Sync dotfile from root directory
dotfiles=()
while IFS=  read -r -d $'\0'; do
  dotfiles+=($REPLY)
done < <(find $HOME/dotfiles -maxdepth 1 -type f -print0)

for src in "${dotfiles[@]}"
do
  if [  $(basename $src) == "dotfiles-install.sh" ] || [ $(basename $src) == "dotfiles-sync.sh" ]; then continue; fi
  dest=${src/\/dotfiles\///}
  ln -sf $src $dest
done

# install plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' > /dev/null 2>&1
