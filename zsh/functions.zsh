function colours() {
    for i in {0..255}; do
        printf "\x1b[38;5;${i}mcolours${i}"
        if (( $i % 5 == 0 )); then
            printf "\n"
        else
            printf "\t"
        fi
    done
}
