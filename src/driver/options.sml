(* Command line options. *)
structure Options =
struct
  val output : string option ref = ref NONE
  val inputs : string list ref = ref []
  val noPrelude = ref false
  val basisAll = ref false         (* --basis all: every file of the basis library *)
  val basisDeps = ref false        (* --basis-deps: print the files that would be loaded *)
  val basisCheck = ref false       (* --basis-check: verify lib/basis/MANIFEST *)
  val allowPrim = ref false
  val orPatterns = ref false
  val defaultInt64 = ref false     (* --default-type=int64 *)
  val defaultWord64 = ref false    (* --default-type=word64 *)
  (* No default: every bin/rune* is a wrapper that passes --lib. *)
  val libDir : string option ref = ref NONE
  val libraries : string list ref = ref []     (* --library NAME: libraries besides the basis *)
  val dumpTokens = ref false
  val dumpAst = ref false
  val typecheckOnly = ref false
  val units = ref false                        (* --units: a unit per file, linked (docs/units.md) *)
  val emitUnits : string option ref = ref NONE (* --emit-units DIR: each unit's file there too *)
  val cacheDir : string option ref = ref NONE  (* --cache-dir DIR: the cache of units (UnitCache) *)
  val noCache = ref false                      (* --no-cache: compile every unit *)
  val explainRebuild = ref false               (* --explain-rebuild: say why each unit was compiled *)
  val verifyCache = ref false                  (* --verify-cache: compile each unit found, and compare *)
  val noWarnings = ref false
  val showVersion = ref false
  val showHelp = ref false
  val readMid : string option ref = ref NONE   (* --read-mid FILE: a Mid program, not SML *)
  val midRoundTrip = ref false                 (* --mid-roundtrip: check MidText against itself *)
  val target = ref "registers"                 (* --target=T: the bytecode made (Target) *)

  val usage =
    "usage: rune [options] file.sml ...\n\
    \\n\
    \Compile Standard ML source files to Rune bytecode (run with runevm).\n\
    \\n\
    \  -o FILE           write bytecode to FILE (default: first input with .rbc)\n\
    \  --lib DIR         directory containing the basis library, in DIR/basis\n\
    \                    (required unless --no-prelude)\n\
    \  --library NAME    compile the library LIBDIR/NAME (a MANIFEST like the basis\n\
    \                    library's) and those it names, after the basis library\n\
    \                    and before the inputs; NAME is a path if it begins with\n\
    \                    / or .; repeatable\n\
    \  --no-prelude      do not compile the basis library before the inputs\n\
    \  --basis MODE      demand (default): compile the files of the basis library\n\
    \                    that the inputs name, and what those need; all: every file\n\
    \  --basis-deps      print the library files the inputs load, and exit\n\
    \  --basis-check     check the provides and requires columns of the basis\n\
    \                    library's MANIFEST, and of those of --library, against\n\
    \                    their sources, and exit\n\
    \  --allow-prim      allow the _prim extension in the inputs\n\
    \  --int-bits=N      the precision of int and word on the VM: 63 (default), or\n\
    \                    64 for a VM built with -DRUNE_INT64\n\
    \  --or-patterns     allow or-patterns (p1 | p2), which are not Standard ML\n\
    \  --default-type=T  in the input files, the type of an int or word constant or\n\
    \                    operator that its declaration leaves open: int (default)\n\
    \                    or int64, word (default) or word64\n\
    \  --flex-records=M  what must determine a flexible record's labels\n\
    \                    (docs/language.md): binding, declaration,\n\
    \                    topdec-monomorphic, topdec (default) or program\n\
    \  --units           compile every file, of the basis library too, as a unit\n\
    \                    of its own after the files before it, and link them\n\
    \                    (docs/units.md)\n\
    \  --emit-units DIR  with --units, write each unit's code (.rbu) and basis\n\
    \                    (.rbi) into DIR too, and DIR/units, their names in\n\
    \                    order; `rune -o P.rbc` given those files links them\n\
    \  --cache-dir DIR   with --units, keep each unit compiled in the cache in DIR\n\
    \                    and take it from there when nothing it was compiled from\n\
    \                    changed (default: $RUNE_CACHE, else .rune beside the\n\
    \                    first input; docs/units.md)\n\
    \  --no-cache        with --units, compile every unit\n\
    \  --explain-rebuild with --units, say of each unit whether it was taken from\n\
    \                    the cache, or why it was compiled\n\
    \  --verify-cache    with --units, compile each unit the cache has too, and\n\
    \                    fail where the cache's is not what compiling it gives\n\
    \  --typecheck-only  stop after type checking\n\
    \  --type-work=N     type traversal budget per top-level declaration (50000000)\n\
    \  --match-work=N    pattern-analysis budget per match (1000000)\n\
    \  --no-warnings     do not print warnings (nonexhaustive or redundant matches)\n\
    \  --dump-tokens     print the tokens of the input files and stop\n\
    \  --dump-ast        print the parsed program\n\
    \  --dump-lambda     print the intermediate representation (--dump-after=translate)\n\
    \  --dump-code       print the generated bytecode (--dump-after=registers, or\n\
    \                    stack with --target=stack)\n\
    \  -O0, -O1, -O2     the optimisation level (default -O1)\n\
    \  --passes=P,...    run these optional passes, whatever the level\n\
    \  --dump-before=P   print what the pass P is given (all: every pass)\n\
    \  --dump-after=P    print what the pass P makes (all: every pass)\n\
    \  --lint            check what every pass makes (docs/ir.md)\n\
    \  --fuel=N          make no more than N rewrites (scripts/bisect-fuel.sh)\n\
    \  --pass-stats      print the size and the time of every pass\n\
    \  --read-mid FILE   read a Mid program as --dump-after=mid prints it, and\n\
    \                    make and check it as the pass mid would, but no bytecode\n\
    \  --mid-roundtrip   check that Mid printed, read and printed again is the same\n\
    \  --target=T        the bytecode to make: registers (runevm's, the default,\n\
    \                    from -O1) or stack (runevm-stack's)\n\
    \  --version         print the version and exit\n\
    \  --help            print this message\n"

  exception Usage of string

  (* An option of the form --name=value, as (--name, value). *)
  fun valued (a : string) : (string * string) option =
    if String.isPrefix "--" a then
      case CharVector.findi (fn (_, c) => c = #"=") a of
        SOME (i, _) => SOME (String.substring (a, 0, i), String.extract (a, i + 1, NONE))
      | NONE => NONE
    else NONE

  (* --flex-records=MODE, before the options of fixed spelling *)
  fun parse (args : string list) : unit =
    case args of
      arg :: rest =>
        if String.isPrefix "--flex-records=" arg then
          let val m = String.extract (arg, size "--flex-records=", NONE)
          in
            case Elaborate.flexModeOf m of
              SOME mode => (Elaborate.flexRecords := mode; parse rest)
            | NONE => raise Usage ("--flex-records: binding, declaration, topdec-monomorphic, topdec or program, not " ^ m)
          end
        else parse' args
    | [] => ()
  and parse' (args : string list) : unit =
    case args of
      [] => ()
    | "-o" :: f :: rest => (output := SOME f; parse rest)
    | ["-o"] => raise Usage "-o requires an argument"
    | "--lib" :: d :: rest => (libDir := SOME d; parse rest)
    | ["--lib"] => raise Usage "--lib requires an argument"
    | "--library" :: n :: rest => (libraries := !libraries @ [n]; parse rest)
    | ["--library"] => raise Usage "--library requires a name"
    | "--no-prelude" :: rest => (noPrelude := true; parse rest)
    | "--basis" :: "all" :: rest => (basisAll := true; parse rest)
    | "--basis" :: "demand" :: rest => (basisAll := false; parse rest)
    | "--basis" :: _ => raise Usage "--basis requires all or demand"
    | "--basis-deps" :: rest => (basisDeps := true; parse rest)
    | "--basis-check" :: rest => (basisCheck := true; parse rest)
    | "--allow-prim" :: rest => (allowPrim := true; parse rest)
    | "--int-bits=63" :: rest => (Overload.setIntBits 63; Target.intBits := 63; parse rest)
    | "--int-bits=64" :: rest => (Overload.setIntBits 64; Target.intBits := 64; parse rest)
    | "--or-patterns" :: rest => (orPatterns := true; parse rest)
    | "--default-type=int" :: rest => (defaultInt64 := false; parse rest)
    | "--default-type=int64" :: rest => (defaultInt64 := true; parse rest)
    | "--default-type=word" :: rest => (defaultWord64 := false; parse rest)
    | "--default-type=word64" :: rest => (defaultWord64 := true; parse rest)

    | "--units" :: rest => (units := true; parse rest)
    | "--emit-units" :: d :: rest => (emitUnits := SOME d; parse rest)
    | ["--emit-units"] => raise Usage "--emit-units requires a directory"
    | "--cache-dir" :: d :: rest => (cacheDir := SOME d; parse rest)
    | ["--cache-dir"] => raise Usage "--cache-dir requires a directory"
    | "--no-cache" :: rest => (noCache := true; parse rest)
    | "--explain-rebuild" :: rest => (explainRebuild := true; parse rest)
    | "--verify-cache" :: rest => (verifyCache := true; parse rest)
    | "--typecheck-only" :: rest => (typecheckOnly := true; parse rest)
    | "--no-warnings" :: rest => (noWarnings := true; parse rest)
    | "--dump-tokens" :: rest => (dumpTokens := true; parse rest)
    | "--dump-ast" :: rest => (dumpAst := true; parse rest)
    | "--dump-lambda" :: rest => (Pass.dumpAfter := !Pass.dumpAfter @ ["translate"]; parse rest)
    | "--dump-code" :: rest => (Pass.dumpAfter := !Pass.dumpAfter @ ["stack", "registers"]; parse rest)
    | "-O0" :: rest => (Pass.level := 0; parse rest)
    | "-O1" :: rest => (Pass.level := 1; parse rest)
    | "-O2" :: rest => (Pass.level := 2; parse rest)
    | "--lint" :: rest => (Pass.lint := true; parse rest)
    | "--read-mid" :: f :: rest => (readMid := SOME f; parse rest)
    | ["--read-mid"] => raise Usage "--read-mid requires a file"
    | "--mid-roundtrip" :: rest => (midRoundTrip := true; parse rest)
    | "--pass-stats" :: rest => (Pass.stats := true; parse rest)
    | "--version" :: rest => (showVersion := true; parse rest)
    | "--help" :: rest => (showHelp := true; parse rest)
    | "-h" :: rest => (showHelp := true; parse rest)
    | a :: rest =>
        (case valued a of
           SOME ("--passes", v) => (Pass.only := SOME (String.fields (fn c => c = #",") v); parse rest)
         | SOME ("--dump-before", v) => (Pass.dumpBefore := !Pass.dumpBefore @ [v]; parse rest)
         | SOME ("--dump-after", v) => (Pass.dumpAfter := !Pass.dumpAfter @ [v]; parse rest)
         | SOME ("--target", v) =>
             if v = "stack" orelse v = "registers" then (target := v; parse rest)
             else raise Usage "--target requires stack or registers"
         | SOME ("--fuel", v) =>
             (case Int.fromString v of
                SOME n => if n >= 0 then (Pass.fuel := SOME n; parse rest) else raise Usage "--fuel requires a number"
              | NONE => raise Usage "--fuel requires a number")
         | SOME ("--type-work", v) => (Types.workLimit := workCount ("--type-work", v); parse rest)
         | SOME ("--match-work", v) => (Exhaust.workLimit := workCount ("--match-work", v); parse rest)
         | _ =>
             if String.isPrefix "-" a andalso a <> "-" then raise Usage ("unknown option: " ^ a)
             else (inputs := !inputs @ [a]; parse rest))
  and workCount (option, text) =
    let
      fun bad () = raise Usage (option ^ " requires a positive integer at most 1000000000")
      fun digit (c, n) =
        if not (Char.isDigit c) then bad ()
        else let val d = Char.ord c - Char.ord #"0"
             in if n > (1000000000 - d) div 10 then bad () else n * 10 + d end
      val n = List.foldl digit 0 (String.explode text)
    in if n = 0 then bad () else n end
end
