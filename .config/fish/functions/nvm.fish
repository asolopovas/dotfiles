function nvm
    if test -f $HOME/.nvm/nvm.sh
        set nvmDir $HOME/.nvm/nvm.sh
    else
        set nvmDir $HOME/.config/nvm/nvm.sh
    end

    if type -q bass; and type -f $nvmDir
        bass source $nvmDir --no-use ';' nvm $argv
    end
end
