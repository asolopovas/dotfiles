# Defined in - @ line 1
function gc --wraps='git add -A && git commit -m' --description 'alias gc git add -A && git commit -m'
  git add -A && git commit -m $argv;
end
