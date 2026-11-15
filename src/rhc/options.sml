(* rhc's command line (the haskell98 roadmap, M8): what is read, how far it
   goes, and the options it shares with rune through Pass -- the level of
   lint, the stages to print. *)
structure RhcOptions =
struct
  exception Usage of string

  (* --eta=pedantic|ghc: the Core simplifier's eta rule (D48), the
     pedantic (C), the default, the Report's, or GHC's default (D), an
     option outside the Report, which breaks seq on a partial application
     (the owner's decision of 2026-11-14) *)
  val eta = ref CoreSimplify.Pedantic
  (* --simplify-stats: the Core simplifier's rewrites, by kind, on
     standard error *)
  val simplifyStats = ref false
  (* whether the Core simplifier's core-cheap runs at -O2, a let of a cheap
     and total expression made a case (D51's C, the owner's of 2026-11-14);
     --no-cheap-eagerness turns it off *)
  val cheap = ref true
  (* --unfoldings: at -O2, each unit's unfoldings and its functions'
     strictness signatures written into its interface (M23, M24), which no
     client reads yet, and the unit's configuration saying so, so that an
     entry with them and one without do not share; off by default.
     RhcSyntax sets it, with the level, before the units are made *)
  val unfoldings = ref false

  type options =
    {readCore : string list,          (* --read-core FILE: Core text, read in order as one program *)
     typecheckOnly : bool,            (* stop after the checks *)
     steps : int option,              (* --steps=N: the interpreter's bound on its steps *)
     depth : int,                     (* --depth=N: its bound on the depth of its stack *)
     lintRules : bool,                (* --lint-rules: print CoreLint's rules *)
     generate : int option,           (* --generate-core=SEED: print a generated program *)
     output : string option,          (* -o FILE: compile to bytecode, through Mid, in place of running *)
     units : bool,                    (* --units: with -o, each --read-core file a unit, compiled apart and linked *)
     store : string option,           (* --store DIR: with --units, the store a unit is kept in and taken from;
                                         --no-store, none (a program of Haskell's: RhcSyntax) *)
     layers : string list,            (* --layer DIR: a store a unit is taken from and never kept in *)
     showUnits : bool,                (* --show-units: say of each unit whether it was compiled or taken *)
     linkWhole : bool,                (* --link=whole: the units' Core joined, what main reaches compiled whole *)
     fault : CoreToMid.fault option,  (* --fault=NAME: a fault of Core to Mid made on purpose, for its tests *)
     strings : CoreRuntime.strings,   (* --strings=lazy|whole: how a string literal becomes its list (D24) *)
     help : bool,
     version : bool}

  val usage =
    "usage: rhc [OPTION...] --read-core FILE... [-- ARG...]\n\
    \       rhc [--parse-only | --print | --print-layout | --print-exact | --dump-tokens\n\
    \            | --dump-ast [--no-spans]] FILE.hs\n\
    \       rhc [--typecheck-only | --desugar-only] [NAME OPTION...] FILE.hs [-o OUT | -- ARG...]\n\
    \       rhc --dump-names [NAME OPTION...] FILE.hs...\n\
    \       rhc --dump-types | --dump-evidence | --dump-derived [NAME OPTION...] FILE.hs\n\
    \       rhc --dump-hslint [NAME OPTION...] FILE.hs\n\
    \       rhc [--store DIR | --no-store] [--layer DIR] [--show-units] FILE.hs [-o OUT]\n\
    \       rhc --prune-store DIR | --identity | --hslint-rules | --lint-rules\n\
    \rhc is the Haskell 98 compiler of the haskell98 roadmap (docs/rhc.md). It\n\
    \reads a program of Haskell, a file and the modules it imports, checks it,\n\
    \desugars it to Core, its typed lazy intermediate language, and runs that\n\
    \on Core's interpreter or with -o compiles it to Rune's bytecode, the\n\
    \library's units taken from the snapshot bin/rhc names; and it reads Core\n\
    \text, checks it and runs or compiles it. A check or a compile of a\n\
    \program keeps its units in a store, .rhc beside FILE.hs (RHC_STORE names\n\
    \another, and an empty one none), and takes them from there the next time.\n\
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
    \  --dump-iface          print each of FILE.hs's modules' interface: its items' text and\n\
    \                        fingerprints (M21)\n\
    \  --dump-usages         print what each unit of FILE.hs's program reads of its imports (M21)\n\
    \  --by-interface        with --typecheck-only, check each group of the program from the\n\
    \                        interfaces of the groups before it (M21)\n\
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
    \  --whole               read, check and desugar the library too, not take its units\n\
    \                        from the snapshot bin/rhc names (bin/rhc.layer, D45)\n\
    \  --snapshot DIR        a store the library's units are taken from, read only, by a\n\
    \                        check and a compile of Haskell (bin/rhc gives it)\n\
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
    \  -- ARG...             the arguments of the program, where rhc runs it on Core's\n\
    \                        interpreter (getArgs), as runevm takes them after its file\n\
    \  --units               with -o, each --read-core file a unit, after rhc's runtime's,\n\
    \                        compiled apart and linked; a program of Haskell is compiled\n\
    \                        a unit at a time, each group of its module graph, without it\n\
    \  --store DIR           keep each unit in the store DIR, not .rhc, and take it from\n\
    \                        there where what it read is as it was; of Core, with --units\n\
    \  --no-store            keep nothing, and take the units from the layers alone\n\
    \  --prune-store DIR     drop from the store DIR every configuration another rhc made,\n\
    \                        which make does to bin/rhc.layer after each build of rhc\n\
    \  --layer DIR           a store a unit is taken from and never kept in\n\
    \  --show-units          say of each unit whether it was compiled or taken\n\
    \  --link=whole|units    with --units, join the units' Core and compile what main\n\
    \                        reaches whole (whole), or link each unit's code (units, the\n\
    \                        default)\n\
    \  -O0, -O1, -O2         the level of Mid's optional passes (default: 1); at -O2 the\n\
    \                        Core simplifier too: core-simplify, core-specialise,\n\
    \                        core-eta, core-strict, core-cheap, core-simplify-2 (M23, M24, D51),\n\
    \                        and a match by Sestoft's trees (--match=sestoft, D34)\n\
    \  --eta=E               the Core simplifier's eta-expansion (D48): pedantic, the default,\n\
    \                        the Report's, only where the expression is a value already; or\n\
    \                        ghc, GHC's default, through a case and IO, which departs from the\n\
    \                        Report: seq of a partial application can converge where it must\n\
    \                        be a bottom (D55's bottom probe, tests/hs/simplify/eta.hs)\n\
    \  --strictness=S        at -O2, on (default): workers and wrappers of the strict\n\
    \                        parameters (M24); off, for E3's L2 step measured\n\
    \  --simplify-stats      the Core simplifier's rewrites, by kind, on standard error\n\
    \  --unfoldings          at -O2, write each unit's unfoldings and strictness signatures\n\
    \                        into its interface, which no client reads yet (M23, M24)\n\
    \  --no-cheap-eagerness  at -O2, leave a let of a cheap and total expression a\n\
    \                        suspension, which core-cheap makes a case (D51)\n\
    \  --fuel=N              make no more than N rewrites of the passes, Core's and Mid's\n\
    \  --target=T            the bytecode: registers (default) or stack\n\
    \  --thunks=c            suspensions in Mid by form C's primitives, the one form there is\n\
    \  --fault=F             for the tests of what catches it, a fault of Core to Mid made\n\
    \                        on purpose: thunk-in-slot, force-behind-cast or susp-type-arg\n\
    \  --strings=S           a string literal's list: lazy, a cell as it is read (default),\n\
    \                        or whole, every cell at once, for D24's measurement\n\
    \  --desugar-only        on a program of Haskell: check it, desugar it to Core, CoreLint\n\
    \                        that, and run nothing (with --dump-after=desugar, print it)\n\
    \  --desugar-units       on a program of Haskell: desugar it a unit at a time, each group of\n\
    \                        modules after the interfaces of those before, and join the units\n\
    \  --canonical-core      with --dump-after=desugar, print what main reaches of the Core,\n\
    \                        types, then imports, then values, each by name: one form of one\n\
    \                        program's Core however it was made (hs/snapshot's comparison)\n\
    \  --match=M             the order of a match in Haskell: report, the Report's, a clause\n\
    \                        after another, the default at -O0 and -O1; or sestoft, decision\n\
    \                        trees that make no test the tests made decide, forcing what the\n\
    \                        Report's order forces, the default at -O2 and above (D34)\n\
    \  --lint-rules          print the name of each rule of CoreLint, one a line\n\
    \  --generate-core=SEED  print a well-typed Core program made from SEED (D55)\n\
    \  --version             print the version and the identity of rhc\n\
    \  --identity            print rhc's identity alone (a digest of its sources)\n\
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
      val units = ref false
      val store = ref NONE
      val noStore = ref false
      val layers = ref []
      val showUnits = ref false
      val linkWhole = ref false
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
        | go ("--units" :: rest) = (units := true; go rest)
        | go ("--store" :: d :: rest) = (store := SOME d; go rest)
        | go ("--no-store" :: rest) = (noStore := true; go rest)
        | go ["--store"] = raise Usage "--store takes a directory"
        | go ("--layer" :: d :: rest) = (layers := !layers @ [d]; go rest)
        | go ["--layer"] = raise Usage "--layer takes a directory"
        | go ("--show-units" :: rest) = (showUnits := true; go rest)
        | go ("--link=whole" :: rest) = (linkWhole := true; go rest)
        | go ("--link=units" :: rest) = (linkWhole := false; go rest)
        | go ["-o"] = raise Usage "-o takes a file"
        | go ("-O0" :: rest) = (Pass.level := 0; go rest)
        | go ("-O1" :: rest) = (Pass.level := 1; go rest)
        | go ("-O2" :: rest) = (Pass.level := 2; go rest)
        | go ("--target=registers" :: rest) = (CompilerSettings.target := "registers"; go rest)
        | go ("--target=stack" :: rest) = (CompilerSettings.target := "stack"; go rest)
        | go ("--thunks=c" :: rest) = go rest
        | go ("--fault=thunk-in-slot" :: rest) = (fault := SOME CoreToMid.ThunkInSlot; go rest)
        | go ("--fault=force-behind-cast" :: rest) = (fault := SOME CoreToMid.ForceBehindCast; go rest)
        | go ("--eta=pedantic" :: rest) = (eta := CoreSimplify.Pedantic; go rest)
        | go ("--eta=ghc" :: rest) = (eta := CoreSimplify.Ghc; go rest)
        | go ("--strictness=on" :: rest) = (CoreStrict.enabled := true; go rest)
        | go ("--strictness=off" :: rest) = (CoreStrict.enabled := false; go rest)
        | go ("--simplify-stats" :: rest) = (simplifyStats := true; go rest)
        | go ("--no-cheap-eagerness" :: rest) = (cheap := false; go rest)
        | go ("--unfoldings" :: rest) = go rest
        | go ("--fault=susp-type-arg" :: rest) = (fault := SOME CoreToMid.SuspTypeArg; go rest)
        | go ("--strings=lazy" :: rest) = (strings := CoreRuntime.Lazy; go rest)
        | go ("--strings=whole" :: rest) = (strings := CoreRuntime.Whole; go rest)
        | go (arg :: rest) =
            (case (after ("--lint=", arg), after ("--dump-after=", arg), after ("--steps=", arg),
                   after ("--depth=", arg), after ("--generate-core=", arg)) of
               (NONE, NONE, NONE, NONE, NONE) =>
                 (case after ("--fuel=", arg) of
                    SOME n => Pass.fuel := SOME (count ("--fuel", 0, n))
                  | NONE => raise Usage ("unknown option or argument: " ^ arg))
             | (SOME l, _, _, _, _) =>
                 (case Pass.levelOf l of
                    SOME n => if l = "off" orelse CharVector.all Char.isDigit l andalso n >= 0 andalso n <= 3
                              then Pass.lintGiven := SOME n
                              else raise Usage ("--lint takes off or 0 to 3: " ^ l)
                  | NONE => raise Usage "--lint= takes a level")
             | (_, SOME s, _, _, _) => Pass.dumpAfter := !Pass.dumpAfter @ stages s
             | (_, _, SOME n, _, _) => steps := SOME (count ("--steps", 1, n))
             | (_, _, _, SOME n, _) => depth := count ("--depth", 1, n)
             | (_, _, _, _, SOME n) => generate := SOME (count ("--generate-core", 0, n));
             go rest)
    in
      go args;
      {readCore = !readCore, typecheckOnly = !typecheckOnly, steps = !steps, depth = !depth,
       lintRules = !lintRules, generate = !generate, output = !output, units = !units, store = if !noStore then NONE else !store, layers = !layers,
       showUnits = !showUnits, linkWhole = !linkWhole, fault = !fault,
       strings = !strings, help = !help, version = !version}
    end
end
