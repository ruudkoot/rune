# bash completion for rune(1), runevm(1) and runevm-stack(1).

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
        COMPREPLY=($(compgen -W '-o -i --lib --no-prelude --basis --basis-deps --basis-check --allow-prim --or-patterns
            --default-type=int --default-type=int64 --default-type=word --default-type=word64
            --typecheck-only --flex-records= --units --emit-units --cache-dir --no-cache --explain-rebuild --color=always --color=never --color=auto --diagnostics=full --diagnostics=short --diagnostics-json -j --jobs --serve --verify-cache --whole --build --build-list --path --basis-index --deps --deps-dot -I --no-warnings --dump-tokens --dump-ast
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
        --heap-size|--heap-fill|--gc-stress|--name)
            return
            ;;
        --restore)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '--heap-size --heap-fill --disasm --trace --stats --count
            --gc-stress --emulate-fork --restore --name --jit=off --jit=baseline --jit=opt --jit=all
            --version --help' -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -f -X '!*.rbc' -- "$cur") $(compgen -d -- "$cur"))
}
complete -F _runevm runevm runevm-stack
