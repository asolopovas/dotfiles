function load_nvm --on-variable="PWD"
  set -l default_NODE_VERSIONsion (nvm version default)
  set -l NODE_VERSIONsion (nvm version)
  set -l nvmrc_path (nvm_find_nvmrc)
  if test -n "$nvmrc_path"
    set -l nvmrc_NODE_VERSIONsion (nvm version (cat $nvmrc_path))
    if test "$nvmrc_NODE_VERSIONsion" = "N/A"
      nvm install (cat $nvmrc_path)
    else if test nvmrc_NODE_VERSIONsion != NODE_VERSIONsion
      nvm use $nvmrc_NODE_VERSIONsion
    end
  else if test "$NODE_VERSIONsion" != "$default_NODE_VERSIONsion"
    # echo "Reverting to default Node version"
    nvm use default > /dev/null
  end
end
