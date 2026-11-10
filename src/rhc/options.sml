(* rhc's command line (the haskell98 roadmap, M8): what is read, how far it
   goes, and the options it shares with rune through Pass -- the level of
   lint, the stages to print. *)
structure RhcOptions =
struct
  exception Usage of string

  type options =
    {readCore : string list,          (* --read-core FILE: Core text, read in order as one program *)
     typecheckOnly : bool,            (* stop after the checks *)
     steps : int option,              (* --steps=N: the interpreter's bound on its steps *)
     depth : int,                     (* --depth=N: its bound on the depth of its stack *)
     lintRules : bool,                (* --lint-rules: print CoreLint's rules *)
     generate : int option,           (* --generate-core=SEED: print a generated program *)
     help : bool,
     version : bool}

  val usage =
    "usage: rhc [OPTION...] --read-core FILE...\n\
    \       rhc [--parse-only | --print | --print-layout | --print-exact | --dump-tokens\n\
    \            | --dump-ast [--no-spans]] FILE.hs\n\
    \       rhc [--typecheck-only] [NAME OPTION...] FILE.hs [-o OUT]\n\
    \       rhc --dump-names [NAME OPTION...] FILE.hs...\n\
    \rhc is the Haskell 98 compiler of the haskell98 roadmap. As yet it reads\n\
    \Core, its typed lazy intermediate language, checks it and runs it on\n\
    \Core's interpreter; and it reads a program of Haskell, a file and the\n\
    \modules it imports, no further than its names and fixity.\n\
    \\n\
    \  --parse-only          read FILE.hs (or .lhs, a literate file) and stop\n\
    \  --print               print it with every block in braces\n\
    \  --print-layout        print it with every block by layout\n\
    \  --print-exact         print it from its tree, comments and layout as they were\n\
    \  --dump-tokens         print the tokens of its layout (the Report's L), one a line\n\
    \  --dump-ast            print its tree, with --no-spans without where each node is\n\
    \  --dump-names          print the exports, fixities and instances of the program of\n\
    \                        FILE.hs... and its library, and its errors of names, sorted\n\
    \  --names=least|greatest  the solution of a cycle's exports (D29): the least fixpoint,\n\
    \                        the default, or the greatest; chapter 5 is met by either\n\
    \  --cycle-default=module|scc  in a cycle of modules, each module's default declaration\n\
    \                        and Rule 2 at its end, the default, or the cycle's (D30: an\n\
    \                        extension, which the checker of M13 reads)\n\
    \  --dotted-names        read a module name with dots, Data.List, as one, which Haskell\n\
    \                        98's modid is not (D35); module A.B is the file A/B.hs\n\
    \  --share DIR           where rhc's library is, DIR/haskell98 (bin/rhc gives it)\n\
    \  --read-core FILE      read FILE as Core text; given again, the files make one program\n\
    \  --typecheck-only      read and check, and run nothing: on a program of Haskell, its\n\
    \                        names and fixity, until the checker lands (M13)\n\
    \  --lint[=N]            the level of the checks: off, 0 to 3 (a bare --lint is 2);\n\
    \                        3 reads Core's text back after every stage (RUNE_LINT too)\n\
    \  --dump-after=STAGE    print the Core a stage makes: read, or all\n\
    \  --pass-stats          the time and size of every stage, on standard error\n\
    \  --steps=N             stop the interpreter after N steps, a bottom (default: none)\n\
    \  --depth=N             the deepest the interpreter's stack may go, a bottom past it\n\
    \                        (default: 10000000)\n\
    \  --lint-rules          print the name of each rule of CoreLint, one a line\n\
    \  --generate-core=SEED  print a well-typed Core program made from SEED (D55)\n\
    \  --version             print the version and the identity of rhc\n\
    \  --help                print this\n"

  (* N of --NAME=N, a count of at least `least` *)
  fun count (name, least, s) =
    case Int.fromString s of
      SOME n => if n >= least andalso CharVector.all Char.isDigit s then n
                else raise Usage (name ^ " takes a number of at least " ^ Int.toString least ^ ": " ^ s)
    | NONE => raise Usage (name ^ " takes a number: " ^ s)

  fun after (prefix, s) = if String.isPrefix prefix s then SOME (String.extract (s, size prefix, NONE)) else NONE

  fun parse (args : string list) : options =
    let
      val readCore = ref []
      val typecheckOnly = ref false
      val steps = ref NONE
      val depth = ref 10000000
      val lintRules = ref false
      val generate = ref NONE
      val help = ref false
      val version = ref false
      fun stages s = List.filter (fn x => x <> "") (String.fields (fn c => c = #",") s)
      fun go [] = ()
        | go ("--read-core" :: file :: rest) = (readCore := !readCore @ [file]; go rest)
        | go ["--read-core"] = raise Usage "--read-core takes a file"
        | go ("--typecheck-only" :: rest) = (typecheckOnly := true; go rest)
        | go ("--lint" :: rest) = (Pass.lintGiven := SOME 2; go rest)
        | go ("--pass-stats" :: rest) = (Pass.stats := true; go rest)
        | go ("--lint-rules" :: rest) = (lintRules := true; go rest)
        | go ("--help" :: rest) = (help := true; go rest)
        | go ("--version" :: rest) = (version := true; go rest)
        | go (arg :: rest) =
            (case (after ("--lint=", arg), after ("--dump-after=", arg), after ("--steps=", arg),
                   after ("--depth=", arg), after ("--generate-core=", arg)) of
               (SOME l, _, _, _, _) =>
                 (case Pass.levelOf l of
                    SOME n => if l = "off" orelse CharVector.all Char.isDigit l andalso n >= 0 andalso n <= 3
                              then Pass.lintGiven := SOME n
                              else raise Usage ("--lint takes off or 0 to 3: " ^ l)
                  | NONE => raise Usage "--lint= takes a level")
             | (_, SOME s, _, _, _) => Pass.dumpAfter := !Pass.dumpAfter @ stages s
             | (_, _, SOME n, _, _) => steps := SOME (count ("--steps", 1, n))
             | (_, _, _, SOME n, _) => depth := count ("--depth", 1, n)
             | (_, _, _, _, SOME n) => generate := SOME (count ("--generate-core", 0, n))
             | _ => raise Usage ("unknown option or argument: " ^ arg);
             go rest)
    in
      go args;
      {readCore = !readCore, typecheckOnly = !typecheckOnly, steps = !steps, depth = !depth,
       lintRules = !lintRules, generate = !generate, help = !help, version = !version}
    end
end
