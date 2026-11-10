(* HsLint in rhc (the haskell98 roadmap's M16, D54): the second inference
   on a program whose names and fixity are resolved, through `Pass.checkAt`
   at level 2 (`--lint=2`, `RUNE_LINT=2`, which `bin/rune-test` sets), so
   that a program it refuses that the compile accepts is a bug of rhc's,
   `lint after hslint: FILE:LINE:COL: MESSAGE`; and `rhc --dump-hslint
   FILE.hs`, which prints what it found:

     KIND     module, name :: kind      a type constructor's or a class's
     DERIVED  module, instance          a derived instance with its context
     TYPE     module, name :: type      a binding of the top level, inferred
     SIGNED   module, name :: type      one with a signature
     DEFAULT  module, line:column, predicates -> type   a default it chose

   for the program's modules, in the order it met them, and with
   `--dump-hslint=library` the library's unsigned bindings and defaults
   too; or `REFUSED FILE:LINE:COL: MESSAGE` and status 1 where it refuses
   the program. Until the checker of M13 lands, the compile goes no further
   than names, and HsLint is held to the programs' expectations instead
   (tests/runner/hslint.sml).

   Where the checker has accepted the program, its evidence records (`r`'s
   `evidence`, with the environment `types`) are replayed by Faxén's rules
   and held to the inference as claims (HsLint.check), in every check at
   level 2.

   `--hslint-claims=FILE` holds the inference to a record's claims in the
   dump's form, each difference refused by the rule it breaks
   (`[rule1] ...`); `RHC_HSLINT_FAULT=RULE` reads the first claim that RULE
   checks corrupted, for the test that each rule refuses its fault
   (`hs/hslint/faults`), and `--hslint-rules` names the rules. Once the
   checker's evidence records exist (M13), they are its claims. *)
structure RhcLint =
struct
  structure G = RhcGraph

  (* the program's groups of modules as HsLint reads them *)
  fun groups (g : G.graph, r : RhcNames.result) : HsLint.module list list =
    let
      val byId = List.foldl (fn ((n : G.node, m), acc) => HsStringMap.insert (acc, #id n, m)) HsStringMap.empty (#modules r)
      fun one (n : G.node) =
        case HsStringMap.find (byId, #id n) of
          SOME m => SOME {id = #id n, ast = m, library = #library n}
        | NONE => NONE
    in
      List.map (List.mapPartial one) (#groups g)
    end

  (* the module whose `main` is the program's, if it is named Main *)
  fun mainOf (g : G.graph) =
    case #roots g of
      root :: _ => if HsModules.moduleName root = "Main" then SOME root else NONE
    | [] => NONE

  (* a span's line and column, and its file with them *)
  fun lineColumn (span : HsSource.span) =
    case G.textOf (#file span) of
      SOME t => let val {line, column} = HsSource.position (t, #start span)
                in SOME (Int.toString line ^ ":" ^ Int.toString column) end
    | NONE => NONE

  fun place (span : HsSource.span) =
    case lineColumn span of
      SOME lc => #file span ^ ":" ^ lc
    | NONE => if #file span = "" then "(no place)" else #file span

  fun infer (g, r, cycleDefault) =
    HsLint.infer {groups = groups (g, r), main = mainOf g, cycleDefault = cycleDefault}

  (* --hslint-claims=FILE: a record's claims to hold the inference to, in
     the dump's form, until the checker's evidence records are its claims
     (M13) *)
  val claims : string option ref = ref NONE

  fun readFile path =
    let val ins = TextIO.openIn path
    in TextIO.inputAll ins before TextIO.closeIn ins end

  (* the check at level 2: a refusal is a bug of the compile's; where claims
     are given, each held to what the inference found, and
     RHC_HSLINT_FAULT=RULE reads the first claim RULE checks corrupted *)
  fun check (g : G.graph, r : RhcNames.result, cycleDefault : bool) =
    Pass.checkAt ("hslint", 2)
      (fn () =>
         ignore (HsLint.check {groups = groups (g, r), main = mainOf g, cycleDefault = cycleDefault,
                               records = Option.map (fn env => {table = #evidence r, env = env, derived = #derived r})
                                           (#types r),
                               claims = Option.map (HsLint.claims o readFile) (!claims),
                               where_ = fn sp => getOpt (lineColumn sp, "0:0"),
                               fault = getOpt (OS.Process.getEnv "RHC_HSLINT_FAULT", "")})
         handle HsLint.Refused (span, msg) => raise Error.Bug (place span ^ ": " ^ msg))
      ()

  (* --hslint-rules: each rule of HsLint's comparison and what it holds *)
  fun rules () =
    (List.app (fn (r, what) => print (r ^ "\t" ^ what ^ "\n")) (HsLint.rules @ HsLint.replayRules); OS.Process.success)

  (* --dump-hslint *)
  fun dump (g : G.graph, r : RhcNames.result, cycleDefault : bool, library : bool) : OS.Process.status =
    (print (HsLint.dump (infer (g, r, cycleDefault), fn sp => getOpt (lineColumn sp, "0:0"), library));
     OS.Process.success)
    handle HsLint.Refused (span, msg) => (print ("REFUSED " ^ place span ^ ": " ^ msg ^ "\n"); OS.Process.failure)
end
