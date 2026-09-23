# bash completion for rune(1) and runevm(1).

_rune() {
    local cur prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case $prev in
        --basis)
            COMPREPLY=($(compgen -W 'demand all' -- "$cur"))
            return
            ;;
        --lib)
            COMPREPLY=($(compgen -d -- "$cur"))
            return
            ;;
        -o)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '-o --lib --no-prelude --basis --basis-deps --basis-check --allow-prim
            --typecheck-only --no-warnings --dump-tokens --dump-ast
            --dump-lambda --dump-code --version --help' -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -f -X '!*.sml' -- "$cur") $(compgen -d -- "$cur"))
}
complete -F _rune rune

_runevm() {
    local cur prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case $prev in
        --heap-size|--gc-stress)
            return
            ;;
        --restore)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '--heap-size --disasm --trace --stats --count
            --gc-stress --emulate-fork --restore --version --help' -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -f -X '!*.rbc' -- "$cur") $(compgen -d -- "$cur"))
}
complete -F _runevm runevm
