(* The stages of the compiler from Lambda on, which the batch driver (Main)
   and the resident compiler of the REPL (src/repl) share: Mid, the optional
   passes on it, Lower, the target of --target; and a unit's code with what
   the linker needs of it (docs/units.md). *)
structure Pipeline =
struct
  (* the counters of names that no check may move (Pass.checkAt) *)
  val () = Pass.counters := (fn () => [!Elaborate.stampCounter, !Types.tyconCounter, !Types.tvarCounter,
                                       !Elaborate.nextRecordId, !MidCanon.nextTycon, !Lower.nextFn, !Lower.nextFuncId,
                                       !Code.nextLabel, !UnitBasis.privateNext])

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

  (* A unit's code, as UnitFile wrote it (bytes), read back (UnitFile.read):
     what was written, but for the reader's normal form, and the same bytes
     written again; at level 2, where a unit is made (linting roadmap, E9). The
     reader makes every instruction an Ops of its operands and a jump's
     target a label, numbers the labels afresh, drops those nothing jumps
     to, makes two at one offset one, and may put a label and a position at
     one offset the other way round: Link treats those alike, so labels are
     compared by their offsets, and positions and labels apart. *)
  fun codeRoundTrip (fp : int, bytes : string) (u : Link.unitCode) : unit =
    let
      val (fp', u') = UnitFile.read bytes handle UnitFile.Bad m => Error.bug ("UnitFile.read: " ^ m)
      fun bug m = Error.bug ("the code read back: " ^ m)
      fun ints l = String.concatWith " " (List.map Int.toString l)
      fun item (Code.Op (oc, a)) = "Op " ^ Int.toString oc ^ " [" ^ ints a ^ "]"
        | item (Code.Ops (oc, a)) =
            "Ops " ^ Int.toString oc ^ " ["
            ^ String.concatWith " " (List.map (fn Code.I i => "I" ^ Int.toString i | Code.L l => "L" ^ Int.toString l) a) ^ "]"
        | item (Code.OpLab (oc, l)) = "OpLab " ^ Int.toString oc ^ " " ^ Int.toString l
        | item (Code.OpLabImm (oc, l, i)) = "OpLabImm " ^ Int.toString oc ^ " " ^ Int.toString l ^ " " ^ Int.toString i
        | item (Code.Lab l) = "Lab " ^ Int.toString l
        | item (Code.Pos (a, b, c, d)) = "Pos " ^ ints [a, b, c, d]
      fun norm (Code.Op (oc, a)) = Code.Ops (oc, List.map Code.I a)
        | norm (Code.OpLab (oc, l)) = Code.Ops (oc, [Code.L l])
        | norm (Code.OpLabImm (oc, l, i)) = Code.Ops (oc, [Code.L l, Code.I i])
        | norm it = it
      (* each label by its byte offset in its function *)
      fun offsets items =
        let
          val t : int IntTable.table = IntTable.table 64
          fun go (_, []) = ()
            | go (off, Code.Lab l :: rest) = (IntTable.insert (t, l, off); go (off, rest))
            | go (off, it :: rest) = go (off + Code.itemSize it, rest)
        in go (0, items); fn l => case IntTable.find (t, l) of SOME o' => o' | NONE => ~1 - l end
      fun canonCode items =
        let val off = offsets items
        in
          List.mapPartial (fn it => case norm it of
                                      Code.Lab _ => NONE
                                    | Code.Ops (oc, a) => SOME (Code.Ops (oc, List.map (fn Code.L l => Code.L (off l) | x => x) a))
                                    | x => SOME x) items
        end
      fun canonMeta (_, NONE : Code.meta option) = NONE
        | canonMeta (items, SOME {arity, reps, blocks, loops, result, captures}) =
            let val off = offsets items
            in
              SOME {arity = arity, reps = reps, blocks = List.map (fn (l, ps) => (off l, ps)) blocks, loops = List.map off loops,
                    result = result, captures = captures}
            end
      fun firstDiff (a, b) =
        let
          fun go (i, x :: xs, y :: ys) = if x = y then go (i + 1, xs, ys) else "item " ^ Int.toString i ^ ": " ^ item x ^ " / " ^ item y
            | go (i, [], y :: _) = "item " ^ Int.toString i ^ ": end / " ^ item y
            | go (i, x :: _, []) = "item " ^ Int.toString i ^ ": " ^ item x ^ " / end"
            | go (_, [], []) = "none"
        in go (0, a, b) ^ " (of " ^ Int.toString (List.length a) ^ " and " ^ Int.toString (List.length b) ^ ")" end
      val c = #code u and c' = #code u'
      fun same (x, y, what) = if x = y then () else bug what
    in
      same (fp, fp', "another fingerprint");
      same (String.concat (UnitFile.chunks (fp', u')), bytes, "other bytes written again");
      same (#identity u, #identity u', "another identity");
      same (#provenance u, #provenance u', "another provenance");
      same (#globals u, #globals u', "other globals");
      same (#imports u, #imports u', "other imports");
      same (#exports u, #exports u', "other exports");
      same (#consts c, #consts c', "other constants");
      same (#nglobals c, #nglobals c', "another number of globals");
      same (#files c, #files c', "other files");
      same (#inlines c, #inlines c', "other inlined frames");
      same (#globalReps c, #globalReps c', "other representations of globals");
      same (List.length (#funcs c), List.length (#funcs c'), "another number of functions");
      ListPair.app (fn (f : Code.func, f' : Code.func) =>
                      let
                        val a = canonCode (#code f) and b = canonCode (#code f')
                      in
                        same (#id f, #id f', "function " ^ #name f ^ ": another id");
                        same (#name f, #name f', "function " ^ #name f ^ ": another name " ^ #name f');
                        same (#nlocals f, #nlocals f', "function " ^ #name f ^ ": another number of locals");
                        if a = b then () else bug ("function " ^ #name f ^ ": other code: " ^ firstDiff (a, b));
                        same (canonMeta (#code f, #meta f), canonMeta (#code f', #meta f'), "function " ^ #name f ^ ": another meta")
                      end)
                   (#funcs c, #funcs c')
    end

  (* The stage that makes Mid, from Lambda or from its text: MidLint at the
     boundary, level 1, and Mid's text read back -- from level 1 with
     --mid-roundtrip, and at level 3 *)
  fun midStage (showIn : ('a -> string) option) (f : 'a -> Mid.program) : 'a -> Mid.program =
    Pass.stage {name = "mid", showIn = showIn, show = MidText.show,
                check = fn p => (Pass.checkAt ("mid", 1) MidLint.check p;
                                 Pass.checkAt ("mid-roundtrip", if !CompilerSettings.midRoundTrip then 1 else 3) MidText.roundTrip p),
                size = Mid.size}
               f

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

  (* a unit's Mid as ToMid made it, with what it needs of the tables, kept
     where a whole program is to be made of its units' (--whole; the
     incremental roadmap's M7) *)
  val keepMid = ref false
  val () = CompilerState.cellRoot ("Pipeline.keepMid", keepMid)
  val lastMid : MidCanon.unitMid option ref = ref NONE
  val () = CompilerState.cellRoot ("Pipeline.lastMid", lastMid)

  (* Mid to Low: the optional passes, and Lower. Shake runs on a whole
     program only (Pass.whole), which is renumbered canonically first, as
     one made of its units' Mid is (MidCanon) *)
  fun lowOfMid (mid : Mid.program) : Low.program =
    let
      val mid =
        if !Pass.whole
        then Pass.stage {name = "midcanon", showIn = SOME MidText.show, show = MidText.show,
                         check = fn p => (Pass.checkAt ("midcanon", 1) (MidCanon.checkRenaming mid) p; roundTrip "midcanon" p),
                         size = Mid.size}
                        MidCanon.program mid
        else mid
      (* the optional passes on Mid (docs/ir.md), each linted at level 2;
         whether one ran, so that the boundary before lower is linted at
         level 1 *)
      val passed = ref false
      fun optional (name, f) m =
        if Pass.enabled (name, 1) andalso (name <> "shake" orelse !Pass.whole) then
          (passed := true;
           Pass.stage {name = name, showIn = SOME MidText.show, show = MidText.show,
                       check = fn p => (Pass.lintAt name MidLint.check p; roundTrip name p), size = Mid.size}
                      f m)
        else m
      val () = functorBodies ()
      (* the copies of applications given back (Expand), before anything
         else is done to them; in a build in units, of the unit's own
         functors and those marked to be inlined *)
      val () = Expand.knownFunction := (fn g => IntMap.member (!Lower.knownBefore, g))
      val mid = optional ("expand", Expand.program) mid
      val mid = optional ("shake", Shake.program) mid
      val mid = optional ("lift", Lift.program) mid
      val mid = optional ("workers", Workers.program) mid
      val mid = optional ("simplify", Simplify.program) mid
      val mid = optional ("refs", Refs.program) mid
      (* what the inliner left of the functions it put in place goes *)
      val mid =
        if Pass.enabled ("simplify", 1) andalso Pass.enabled ("inline", 1) then optional ("shake", Shake.program) mid
        else mid
      (* what Lower is given, at the boundary, where no pass's lint saw it
         (level 1 alone: every pass's lint at 2 did) *)
      val () = if !passed andalso Pass.lintLevel () = 1 then Pass.checkAt ("prelower", 1) MidLint.check mid else ()
    in
      Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show, check = fn p => (Pass.checkAt ("lower", 1) LowLint.check p; LowShapes.stage p),
                  size = Low.size}
                 (fn m => lowered (Lower.program (m, !Translate.funNames))) mid
    end

  (* Lambda to Low: Mid, the optional passes on it, and Lower *)
  fun lowOf (lam : Lambda.lexp) : Low.program =
    let
      val mid = midStage (SOME Lambda.show) ToMid.program lam
      val () = if not (!Pass.whole) andalso !keepMid then lastMid := SOME (MidCanon.capture mid) else ()
      (* the marked functors' functions, for the unit's basis *)
      val () = if not (!Pass.whole) then Expand.keepMarked mid else ()
    in lowOfMid mid end

  (* The check of a program's stack code (the linting roadmap's D11 and
     M10): the loader's checks and runeopt's RbcCheck, on the code as its
     file has it. They are runeopt's, built with the driver (rune.build,
     src/driver/stackcheck.sml, which sets this) and not with the compiler
     library, whose files are its own; elsewhere it checks nothing. A
     refusal is Error.Bug. *)
  val stackCheck : (Code.program -> unit) ref = ref (fn _ => ())
  val () = CompilerState.cellRoot ("Pipeline.stackCheck", stackCheck)
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

  (* A unit, elaborated, made into its code and what the linker needs of it
     (Link.sessionCode), with Pass.whole false; the units after it may call
     its functions by name (Lower.knownBefore). *)
  fun unitOf (decs : Ast.dec list) : Link.sessionCode =
    let
      val lam = Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = Pass.checkAt ("translate", 1) LambdaLint.check,
                            size = Lambda.size}
                           Translate.transProgram decs
      val low = lowOf lam
      (* what its functors' and applications' code was made of, which no
         later unit's needs *)
      val () = Elaborate.forgetUnitCode ()
      val code = targetStage low
      val u : Link.sessionCode =
        {code = code, globals = IntMap.listItemsi (!Code.globals), defines = Link.defines low,
         imports = List.map (fn (s, i) => (i, s)) (IntMap.listItemsi (!Lower.imported)),
         exports = IntMap.listItemsi (!Lower.globalFids)}
    in
      Lower.knownBefore := IntMap.foldli (fn (s, _, m) => IntMap.insert (m, s, ())) (!Lower.knownBefore)
                                         (!Lower.globalFids);
      u
    end

  (* unitThrough {start, name, file, text, mode, decs, delta, fixity, used}: the
     unit of decs, elaborated since start, which declared delta and left
     fixity, and looked up the names used, compiled; its basis written and loaded again in place of what the
     compile left, so that the units after it see what the bytes say, as
     they do of a unit from the cache (UnitBasis; docs/units.md). name is
     the unit's, file its source's in spans, text its source and mode how
     it was read. Its code by
     keys, its basis, and what loading gave, which the caller adds to the
     start's environment and fixity. fresh: loaded under an identity no
     unit of the session has (UnitBasis.unused), as the REPL loads a file it
     used before; the code is still the basis's identity's, for the cache,
     and is linked renamed (UnitBasis.renamed). *)
  (* f (), where what a unit keeps between compiles (its basis, its Mid,
     its code, its cache entry) longer than the host's longest array, the
     most a pickle holds, is an error of the unit's (functors-units M8) *)
  fun keeping (file : string) (f : unit -> 'a) : 'a =
    f () handle Pickle.TooLong n =>
      Error.error ({file = file, start = 0, stop = 0},
                   "what this unit keeps between compiles needs " ^ Int.toString n ^ " bytes, more than "
                   ^ Int.toString CharArray.maxLen ^ ", the longest array this host makes")

  fun unitThrough {start : UnitBasis.start, name : string, file : string, text : unit -> string, mode : Source.mode,
                   decs : Ast.dec list, delta : Env.env, fixity : Fixity.env, used : string list, fresh : bool}
      : {code : Link.unitCode, exported : UnitBasis.exported, loaded : UnitBasis.result} =
    keeping file (fn () =>
    let
      val timed = Pass.timed
      val sc = timed "unit-passes" (fn () => unitOf decs)
      val x = timed "unit-export" (fn () => UnitBasis.export {start = start, name = name, file = file, text = text, mode = mode,
                                                             delta = delta, fixity = fixity, used = used})
      val () = timed "unit-undo" (fn () => UnitBasis.undo start)
      val l = timed "unit-load" (fn () => UnitBasis.loadKnown ({pickle = #pickle x, file = file, at = #counters start},
                                                              SOME (if fresh then UnitBasis.unused (#identity x)
                                                                    else #identity x), []))
    in {code = timed "unit-relative" (fn () => UnitBasis.relative (x, sc)), exported = x, loaded = l} end)
end
