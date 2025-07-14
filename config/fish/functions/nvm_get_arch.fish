function nvm_get_arch
    set OS (awk "/^ID=/" /etc/os-release | sed -e "s/ID=//" -e "s/\"//g" | tr "[:upper:]" "[:lower:]")
    if test "$OS" = alpine
        echo "x64-musl"
    end
end
