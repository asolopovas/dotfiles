# Defined in - @ line 1
function gpg2 --wraps='gpg2 --homedir "$XDG_DATA_HOME"/gnupg' --description 'alias gpg2 gpg2 --homedir "$XDG_DATA_HOME"/gnupg'
 command gpg2 --homedir "$XDG_DATA_HOME"/gnupg $argv;
end
