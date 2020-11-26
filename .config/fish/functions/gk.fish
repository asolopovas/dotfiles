# Defined in - @ line 1
function gk --wraps='gitk --all&' --description 'alias gk gitk --all&'
  gitk --all& $argv;
end
