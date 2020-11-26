# Defined in - @ line 1
function update-dev-conf --wraps='yarn remove dev-conf && yarn add https://github.com/asolopovas/dev-conf.git' --description 'alias update-dev-conf yarn remove dev-conf && yarn add https://github.com/asolopovas/dev-conf.git'
  yarn remove dev-conf && yarn add https://github.com/asolopovas/dev-conf.git $argv;
end
