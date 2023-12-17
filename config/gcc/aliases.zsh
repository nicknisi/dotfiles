if [[ -n "$(command -v gcc-13)" ]]; then
    export CC='gcc-13'
    alias gcc='gcc-13'
    alias cc='gcc'
fi
