# Defined in - @ line 1
function gw --wraps='git add -A && git commit -m "save"' --description 'alias gw git add -A && git commit -m "save"'
  git add -A && git commit -m "save" $argv;
end
