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
     output : string option,          (* -o FILE: compile to bytecode, through Mid, in place of running *)
     fault : CoreToMid.fault option,  (* --fault=NAME: a fault of Core to Mid made on purpose, for its tests *)
     strings : CoreRuntime.strings,   (* --strings=lazy|whole: how a string literal becomes its list (D24) *)
     help : bool,
     version : bool}

  val usage =
    "usage: rhc [OPTION...] --read-core FILE...\n\
    \       rhc [--parse-only | --print | --print-layout | --print-exact | --dump-tokens\n\
    \            | --dump-ast [--no-spans]] FILE.hs\n\
    \       rhc [--typecheck-only | --desugar-only] [NAME OPTION...] FILE.hs [-o OUT]\n\
    \       rhc --dump-names [NAME OPTION...] FILE.hs...\n\
    \       rhc --dump-types | --dump-evidence | --dump-derived [NAME OPTION...] FILE.hs\n\
    \       rhc --dump-hslint [NAME OPTION...] FILE.hs\n\
    \rhc is the Haskell 98 compiler of the haskell98 roadmap. It reads Core,\n\
    \its typed lazy intermediate language, checks it and runs it on Core's\n\
    \interpreter, or with -o compiles it; and it reads a program of Haskell,\n\
    \a file and the modules it imports, checks it, desugars it to Core and\n\
    \runs or compiles that.\n\
    \\n\
    \  --parse-only          read FILE.hs (or .lhs, a literate file) and stop\n\
    \  --print               print it with every block in braces\n\
    \  --print-layout        print it with every block by layout\n\
    \  --print-exact         print it from its tree, comments and layout as they were\n\
    \  --dump-tokens         print the tokens of its layout (the Report's L), one a line\n\
    \  --dump-ast            print its tree, with --no-spans without where each node is\n\
    \  --dump-names          print the exports, fixities and instances of the program of\n\
    \                        FILE.hs... and its library, and its errors of names, sorted\n\
    \  --dump-types          print the type of each top-level value of the program's modules,\n\
    \                        and the library's errors (M13)\n\
    \  --dump-evidence       print the checker's evidence records of the program's modules:\n\
    \                        each overloaded use's dictionaries, each binder's type (D31)\n\
    \  --dump-derived        print the methods of the program's derived instances (D33)\n\
    \  --dump-hslint         print the type HsLint's second inference gives each binding of\n\
    \                        the top level of FILE.hs's program, and the defaults it chose\n\
    \  --hslint-claims=FILE  at level 2, hold HsLint's inference to a record's claims, lines\n\
    \                        of the dump's form; RHC_HSLINT_FAULT=RULE corrupts one, for tests\n\
    \  --hslint-rules        print the name of each rule of HsLint's comparison, one a line\n\
    \  --dump-binders        print each local name of FILE.hs's own modules, a line for each\n\
    \                        binding site (BIND) and use (USE): its renamed name, file:start-end\n\
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
    \                        names, fixity, kinds, types and classes\n\
    \  --lint[=N]            the level of the checks: off, 0 to 3 (a bare --lint is 2);\n\
    \                        2 runs HsLint on a program of Haskell, 3 reads Core's text\n\
    \                        back after every stage (RUNE_LINT too)\n\
    \  --dump-after=STAGE    print what a stage makes: read, desugar (Haskell's Core),\n\
    \                        coretomid (Mid's text), mid, a pass on Mid, lower, registers\n\
    \                        or stack, or all\n\
    \  --pass-stats          the time and size of every stage, on standard error\n\
    \  --steps=N             stop the interpreter after N steps, a bottom (default: none)\n\
    \  --depth=N             the deepest the interpreter's stack may go, a bottom past it\n\
    \                        (default: 10000000)\n\
    \  -o FILE               compile to bytecode, through Mid, in place of running\n\
    \  -O0, -O1, -O2         the level of Mid's optional passes (default: 1)\n\
    \  --target=T            the bytecode: registers (default) or stack\n\
    \  --thunks=c            suspensions in Mid by form C's primitives, the one form there is\n\
    \  --fault=F             for the tests of what catches it, a fault of Core to Mid made\n\
    \                        on purpose: thunk-in-slot or force-behind-cast\n\
    \  --strings=S           a string literal's list: lazy, a cell as it is read (default),\n\
    \                        or whole, every cell at once, for D24's measurement\n\
    \  --desugar-only        on a program of Haskell: check it, desugar it to Core, CoreLint\n\
    \                        that, and run nothing (with --dump-after=desugar, print it)\n\
    \  --match=M             the order of a match in Haskell: report, the Report's, a clause\n\
    \                        after another (default), or sestoft, decision trees that make no\n\
    \                        test the tests made decide, for D34's measurement\n\
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
      val output = ref NONE
      val fault = ref NONE
      val strings = ref CoreRuntime.Lazy
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
        | go ("-o" :: file :: rest) = (output := SOME file; go rest)
        | go ["-o"] = raise Usage "-o takes a file"
        | go ("-O0" :: rest) = (Pass.level := 0; go rest)
        | go ("-O1" :: rest) = (Pass.level := 1; go rest)
        | go ("-O2" :: rest) = (Pass.level := 2; go rest)
        | go ("--target=registers" :: rest) = (CompilerSettings.target := "registers"; go rest)
        | go ("--target=stack" :: rest) = (CompilerSettings.target := "stack"; go rest)
        | go ("--thunks=c" :: rest) = go rest
        | go ("--fault=thunk-in-slot" :: rest) = (fault := SOME CoreToMid.ThunkInSlot; go rest)
        | go ("--fault=force-behind-cast" :: rest) = (fault := SOME CoreToMid.ForceBehindCast; go rest)
        | go ("--strings=lazy" :: rest) = (strings := CoreRuntime.Lazy; go rest)
        | go ("--strings=whole" :: rest) = (strings := CoreRuntime.Whole; go rest)
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
       lintRules = !lintRules, generate = !generate, output = !output, fault = !fault,
       strings = !strings, help = !help, version = !version}
    end
end
