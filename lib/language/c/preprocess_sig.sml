(* Target-configured preprocessing without a dependency on a C compiler.

   Area: Languages *)
signature C_PREPROCESS =
sig
  (* A caller-supplied include resolver.

     It receives the including file, requested spelling and
     quote/angle distinction, and whether to continue after the including
     file's search root (`include_next`). It returns a canonical source identity and
     original bytes, or `NONE`. It must not execute source directives. *)
  type resolver = {from : string, name : string, system : bool, next : bool} ->
                  {file : string, text : string} option
  (* A macro after preprocessing, including its defining location. *)
  type macro = {name : string, parameters : string list option, variadic : bool,
                body : CLex.token list, location : CLex.location}
  (* A source-located preprocessing diagnostic. *)
  exception Error of CLex.location * string
  (* `run {source, predefined, resolve, width, maxDepth, maxExpansions}`
     preprocesses one translation unit with an explicit target environment.

     It records every original file read, in first-use order. Active pragmas
     remain as `# pragma ...` newline-delimited tokens for the declaration
     parser; packing information is not discarded.

     Raises: `Error` for malformed directives/macros, missing includes,
     exhausted limits, incompatible redefinition or an active `#error`. *)
  val run : {source : {file : string, text : string},
             predefined : (string * string) list, resolve : resolver,
             width : int, maxDepth : int, maxExpansions : int} ->
            {tokens : CLex.token list, dependencies : string list, macros : macro list}
end
