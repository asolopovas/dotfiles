function nvm_find_nvmrc
  if test -f ~/.nvm/nvm.sh; and type -q bass
    bass source ~/.nvm/nvm.sh --no-use ';' nvm_find_nvmrc
  else if type -q bass
    bass source ~/.config/nvm/nvm.sh --no-use ';' nvm_find_nvmrc
  end
end
