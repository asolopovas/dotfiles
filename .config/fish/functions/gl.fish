# Defined in - @ line 1
function gl --wraps='git pull' --description 'alias gl git pull'
  git pull $argv;
end
