# Defined in - @ line 1
function dcd --wraps='docker-compose -f docker-compose.dev.yml' --description 'alias dcd docker-compose -f docker-compose.dev.yml'
  docker-compose -f docker-compose.dev.yml $argv;
end
