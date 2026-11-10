(* The stages from Mid on, and nothing of a front end: the optional passes
   on Mid as a list a client makes, Lower, the target of --target. A front
   end calls lowOfMid with its list (docs/ir.md, What a front end gives
   Mid); Pipeline is Rune's, which adds the stages before Mid and the
   expansion of functors. The list is a seam, not a proof that a front end
   needs nothing else: the passes still read Pass's settings and
   Target.intBits, and a list in another order is a compiler no test has
   seen. *)
structure MidPipeline =
struct
  (* What Lower made of results in globals, checked after every lower, at
     level 0, always on (LowLint.results; docs/ir.md, Levels): its facts, by
     a function's global, which a known call in Low names by its id *)
  fun lowered (low : Low.program) : Low.program =
    let
      val globals = IntMap.foldli (fn (g, fid, m) => IntMap.insert (m, fid, g)) IntMap.empty (!Lower.globalFids)
      val facts : LowLint.results =
        {global = fn f => IntMap.find (globals, f), fields = fn g => IntMap.find (!Lower.slotFuns, g),
         slots = fn n => getOpt (IntMap.find (!Lower.slotGlobals, n), []), needed = Lower.needed,
         sum = fn g => Option.map Lower.sumsOf (IntMap.find (!Lower.sumFuns, g))}
    in
      Pass.checkAt ("results", 0) (LowLint.results facts) low;
      low
    end

  (* Mid's text read back after a stage that makes Mid, at level 3, after
     every stage (docs/ir.md, Levels) *)
  fun roundTrip (key : string) (p : Mid.program) : unit = Pass.checkAt (key ^ "-roundtrip", 3) MidText.roundTrip p

  (* The stage that makes Mid, from a front end's IR or from its text:
     MidLint at the boundary, level 1, and Mid's text read back -- from
     level 1 with --mid-roundtrip, and at level 3 *)
  fun midStage (showIn : ('a -> string) option) (f : 'a -> Mid.program) : 'a -> Mid.program =
    Pass.stage {name = "mid", showIn = showIn, show = MidText.show,
                check = fn p => (Pass.checkAt ("mid", 1) MidLint.check p;
                                 Pass.checkAt ("mid-roundtrip", if !CompilerSettings.midRoundTrip then 1 else 3) MidText.roundTrip p),
                size = Mid.size}
               (fn x => Fault.mid ("mid", f x))

  (* The functor bodies a unit's basis decoded (UnitBasis; Expand.imported),
     linted at the next unit's passes, at level 0, always on: when they are
     read, the datatypes they name are not yet entered (E9). A whole
     program's passes take what they were given *)
  fun functorBodies () : unit =
    let val bodies = !MidLint.pendingBodies
    in
      MidLint.pendingBodies := [];
      if !Pass.whole orelse null bodies then ()
      else Pass.checkAt ("functor-body", 0) (List.app (fn f => MidLint.check [Mid.Funs [f]])) (List.rev bodies)
    end

  (* what the passes are told of the target --target names *)
  fun targetInfo () : Target.t = if !CompilerSettings.target = "registers" then Regs.info else Stack.info

  (* An optional pass on Mid (docs/ir.md): its name for the options, the
     level it runs from, what else must hold where it runs, and the pass.
     Each is linted at level 2 and read back at level 3 as a stage of Mid. *)
  type midPass = {name : string, from : int, gate : unit -> bool, run : Mid.program -> Mid.program}
  fun pass (name : string, run : Mid.program -> Mid.program) : midPass =
    {name = name, from = 1, gate = fn () => true, run = run}
  (* the program's top level is all there is (Pass.whole): Shake goes by it *)
  fun wholeOnly (name : string, run : Mid.program -> Mid.program) : midPass =
    {name = name, from = 1, gate = fn () => !Pass.whole, run = run}

  (* What a stage from Mid on does inside it, by the names --passes and the
     levels go by, with the level each runs from: no stages of their own
     (docs/ir.md, The pipeline) *)
  val parts : (string * string * int) list =
    [("simplify", "inline", 1), ("simplify", "specialise", 1), ("simplify", "equality", 2), ("lower", "results", 1)]
  fun partEnabled (name : string) : bool =
    case List.find (fn (_, n, _) => n = name) parts of
      SOME (_, _, from) => Pass.enabled (name, from)
    | NONE => Error.bug ("no part " ^ name)
  (* what Simplify and Lower are told to do besides *)
  fun simplifyOptions () : Simplify.options =
    {inline = partEnabled "inline", specialise = partEnabled "specialise", equality = partEnabled "equality"}
  fun lowerOptions () : {results : bool} = {results = partEnabled "results" andalso !Pass.whole}

  (* The passes on Mid that any front end may run, in order, each where it
     is enabled (Pass.enabled, --passes). A client makes its own list with
     the functions below; nothing else names a pass. Shake runs again for
     what the inliner left of the functions it put in place. *)
  val standardPasses : midPass list =
    [wholeOnly ("shake", Shake.program),
     pass ("lift", fn m => Lift.program (targetInfo ()) m),
     pass ("workers", fn m => Workers.program (targetInfo ()) m),
     pass ("simplify", fn m => Simplify.program (simplifyOptions ()) m),
     pass ("refs", Refs.program),
     (* D15 C, a measurement's: the register target alone, where RUNE_UNCURRY=1 (Uncurry) *)
     {name = "uncurry", from = 1, run = Uncurry.program,
      gate = fn () => !Uncurry.enabled andalso !CompilerSettings.target = "registers"},
     {name = "shake", from = 1, run = Shake.program,
      gate = fn () => !Pass.whole andalso Pass.enabled ("simplify", 1) andalso partEnabled "inline"}]
  fun passNames (ps : midPass list) : string list = List.map #name ps
  (* every pass of that name gone; the others keep their order *)
  fun removePass (name : string) (ps : midPass list) : midPass list = List.filter (fn p => #name p <> name) ps
  (* p, before or after the first pass of that name *)
  fun insertBefore (name : string, p : midPass) (ps : midPass list) : midPass list =
    let
      fun go [] = Error.bug ("no pass " ^ name)
        | go (q :: rest) = if #name q = name then p :: q :: rest else q :: go rest
    in go ps end
  fun insertAfter (name : string, p : midPass) (ps : midPass list) : midPass list =
    let
      fun go [] = Error.bug ("no pass " ^ name)
        | go (q :: rest) = if #name q = name then q :: p :: rest else q :: go rest
    in go ps end
  (* p in place of every pass of that name *)
  fun replacePass (name : string, p : midPass) (ps : midPass list) : midPass list =
    List.map (fn q => if #name q = name then p else q) ps

  fun distinct (names : string list) : string list =
    List.foldl (fn (n, ns) => if List.exists (fn m => m = n) ns then ns else ns @ [n]) [] names
  (* The stages from Mid to the target's code, with ps the passes on Mid,
     by the names Pass.stage gives them *)
  fun stageNames (ps : midPass list) : string list =
    ["mid", "midcanon"] @ distinct (passNames ps) @ ["lower", "stack", "registers"]

  (* Mid to Low: the optional passes of the list, and Lower. Shake runs on a
     whole program only (Pass.whole), which is renumbered canonically first,
     as one made of its units' Mid is (MidCanon) *)
  fun lowOfMid (passes : midPass list) (mid : Mid.program) : Low.program =
    let
      val mid =
        if !Pass.whole
        then Pass.stage {name = "midcanon", showIn = SOME MidText.show, show = MidText.show,
                         check = fn p => (Pass.checkAt ("midcanon", 1) (MidCanon.checkRenaming mid) p; roundTrip "midcanon" p),
                         size = Mid.size}
                        (fn m => Fault.mid ("midcanon", MidCanon.program m)) mid
        else mid
      (* the optional passes on Mid (docs/ir.md), each linted at level 2;
         whether one ran, so that the boundary before lower is linted at
         level 1 *)
      val passed = ref false
      fun optional ({name, from, gate, run} : midPass, m) =
        if Pass.enabled (name, from) andalso gate () then
          (passed := true;
           Pass.stage {name = name, showIn = SOME MidText.show, show = MidText.show,
                       check = fn p => (Pass.lintAt name MidLint.check p; roundTrip name p), size = Mid.size}
                      (fn m => Fault.mid (name, run m)) m)
        else m
      val () = functorBodies ()
      val mid = List.foldl optional mid passes
      (* what Lower is given, at the boundary, where no pass's lint saw it
         (level 1 alone: every pass's lint at 2 did) *)
      val () = if !passed andalso Pass.lintLevel () = 1 then Pass.checkAt ("prelower", 1) MidLint.check mid else ()
    in
      Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show,
                  check = fn p => (Pass.checkAt ("lower", 1) LowLint.check p; LowShapes.stage p), size = Low.size}
                 (fn m => lowered (Fault.low ("lower", Lower.program (lowerOptions ()) m))) mid
    end

  (* The check of a program's stack code (the linting roadmap's D11 and
     M10): the loader's checks and runeopt's RbcCheck, on the code as its
     file has it. They are runeopt's, built with the driver (rune.build,
     src/driver/stackcheck.sml, which sets this) and not with the compiler
     library, whose files are its own; elsewhere it checks nothing. A
     refusal is Error.Bug. *)
  val stackCheck : (Code.program -> unit) ref = ref (fn _ => ())
  val () = CompilerState.cellRoot ("MidPipeline.stackCheck", stackCheck)
  (* it, from level 2 of the lint (the roadmap's D12), as a check of
     Pass.checkAt, which --pass-stats counts as "rbccheck"; RUNE_RBCCHECK=1
     runs it at every level, to measure it, and 0 at none *)
  fun checkStack (p : Code.program) : unit =
    case OS.Process.getEnv "RUNE_RBCCHECK" of
      SOME "0" => ()
    | SOME "" => Pass.checkAt ("rbccheck", 2) (!stackCheck) p
    | SOME _ => Pass.checkAt ("rbccheck", Pass.off) (!stackCheck) p
    | NONE => Pass.checkAt ("rbccheck", 2) (!stackCheck) p

  (* Low to the code of the target --target names *)
  fun targetStage (low : Low.program) : Code.program =
    if !CompilerSettings.target = "registers" then
      (* the code checked (RegVerify) as the stage's check, from level 1 or
         where RUNE_REGVERIFY says; corrupted first where
         RUNE_REGVERIFY_INJECT says, for the check's tests *)
      Pass.stage {name = "registers", showIn = SOME Low.show, show = Code.dump, check = RegVerify.stage,
                  size = Code.size}
                 (RegVerify.inject o Regs.program) low
    else
      (* a whole program's, as the stage's check; a unit's is checked in
         the program it is linked into (Main.linkUnits) *)
      Pass.stage {name = "stack", showIn = SOME Low.show, show = Code.dump,
                  check = fn p => if !Pass.whole then checkStack p else (), size = Code.size}
                 Stack.program low

  (* the fingerprint of the bytecode --target names *)
  fun fingerprint () : int = if !CompilerSettings.target = "registers" then RegCodes.fingerprint else Opcodes.fingerprint
end
