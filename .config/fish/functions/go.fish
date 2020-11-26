# Defined in - @ line 1
function go --wraps='git checkout ' --description 'alias go git checkout '
  git checkout  $argv;
end
