# Defined in - @ line 1
function wget --wraps='wget --hsts-file "$XDG_CACHE_HOME/wget-hsts"' --description 'alias wget wget --hsts-file "$XDG_CACHE_HOME/wget-hsts"'
 command wget --hsts-file "$XDG_CACHE_HOME/wget-hsts" $argv;
end
