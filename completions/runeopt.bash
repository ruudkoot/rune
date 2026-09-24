# bash completion for runeopt(1).

_runeopt() {
    local cur prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case $prev in
        -o)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
        --runtime)
            COMPREPLY=($(compgen -d -- "$cur"))
            return
            ;;
        --cc)
            COMPREPLY=($(compgen -c -- "$cur"))
            return
            ;;
        --options)
            return
            ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '-o -S --options --cc --runtime --check --disasm --lines --facts
            --inlined --version --help' -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -f -X '!*.rbc' -- "$cur") $(compgen -d -- "$cur"))
}
complete -F _runeopt runeopt
