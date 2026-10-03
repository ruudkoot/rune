# bash completion for rune(1), runevm(1) and runevm-new(1).

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
            --dump-lambda --dump-code --target=registers --target=stack --version --help' -- "$cur"))
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
        --heap-size|--heap-fill|--gc-stress)
            return
            ;;
        --restore)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '--heap-size --heap-fill --disasm --trace --stats --count
            --gc-stress --emulate-fork --restore --jit=off --jit=baseline --jit=opt --jit=all
            --version --help' -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -f -X '!*.rbc' -- "$cur") $(compgen -d -- "$cur"))
}
complete -F _runevm runevm runevm-new
