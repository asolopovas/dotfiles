# Defined in - @ line 1
function dss --wraps=docker-sync-stack --description 'alias dss docker-sync-stack'
  docker-sync-stack  $argv;
end
