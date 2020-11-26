# Defined in - @ line 1
function xclip --wraps='xclip -selection c' --description 'alias xclip xclip -selection c'
 command xclip -selection c $argv;
end
