# Defined in - @ line 1
function nah --wraps='git reset --hard' --description 'alias nah git reset --hard'
  git reset --hard $argv;
end
