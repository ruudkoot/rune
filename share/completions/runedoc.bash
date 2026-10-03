# bash completion for runedoc(1).

_runedoc() {
    local cur prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case $prev in
        --library|--out|--tests|--examples|--lib)
            COMPREPLY=($(compgen -d -- "$cur"))
            return
            ;;
        --annotations)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
        --title)
            return
            ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '--library --out --check --title --tests --annotations --examples
            --labels --check-coverage --page --dump-ir --lint --lib --version --help' -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -f -X '!*.sml' -- "$cur") $(compgen -d -- "$cur"))
}
complete -F _runedoc runedoc
