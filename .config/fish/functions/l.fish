# Defined in - @ line 1
function l --wraps='ls -la' --description 'alias l ls -la'
  ls -la $argv;
end
