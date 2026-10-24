(* The stages of the compiler from Lambda on, which the batch driver (Main)
   and the resident compiler of the REPL (src/repl) share: Mid, the optional
   passes on it, Lower, the target of --target; and a unit's code with what
   the linker needs of it (docs/units.md). *)
structure Pipeline =
struct
  (* The stage that makes Mid, from Lambda or from its text. *)
  fun midStage (showIn : ('a -> string) option) (f : 'a -> Mid.program) : 'a -> Mid.program =
    Pass.stage {name = "mid", showIn = showIn, show = MidText.show,
                check = fn p => (MidLint.check p; if !CompilerSettings.midRoundTrip then MidText.roundTrip p else ()),
                size = Mid.size}
               f

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
        then Pass.stage {name = "midcanon", showIn = SOME MidText.show, show = MidText.show, check = MidLint.check,
                         size = Mid.size}
                        MidCanon.program mid
        else mid
      (* the optional passes on Mid (docs/ir.md) *)
      fun optional (name, f) m =
        if Pass.enabled (name, 1) andalso (name <> "shake" orelse !Pass.whole) then
          Pass.stage {name = name, showIn = SOME MidText.show, show = MidText.show, check = MidLint.check,
                      size = Mid.size}
                     f m
        else m
      (* --functors=functions: the copies of applications given back
         (Expand, functors-units.md M6), before anything else is done to
         them; in a build in units, of the unit's own functors (D2) *)
      val mid = if !Elaborate.functorFunctions then optional ("expand", Expand.program) mid else mid
      val mid = optional ("shake", Shake.program) mid
      val mid = optional ("lift", Lift.program) mid
      val mid = optional ("workers", Workers.program) mid
      val mid = optional ("simplify", Simplify.program) mid
      val mid = optional ("refs", Refs.program) mid
      (* what the inliner left of the functions it put in place goes *)
      val mid =
        if Pass.enabled ("simplify", 1) andalso Pass.enabled ("inline", 1) then optional ("shake", Shake.program) mid
        else mid
    in
      Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show, check = LowLint.check,
                  size = Low.size}
                 (fn m => Lower.program (m, !Translate.funNames)) mid
    end

  (* Lambda to Low: Mid, the optional passes on it, and Lower *)
  fun lowOf (lam : Lambda.lexp) : Low.program =
    let
      val mid = midStage (SOME Lambda.show) ToMid.program lam
      val () = if not (!Pass.whole) andalso !keepMid then lastMid := SOME (MidCanon.capture mid) else ()
    in lowOfMid mid end

  (* Low to the code of the target --target names *)
  fun targetStage (low : Low.program) : Code.program =
    if !CompilerSettings.target = "registers" then
      Pass.stage {name = "registers", showIn = SOME Low.show, show = Code.dump, check = fn _ => (), size = Code.size}
                 Regs.program low
    else
      Pass.stage {name = "stack", showIn = SOME Low.show, show = Code.dump, check = fn _ => (), size = Code.size}
                 Stack.program low

  (* the fingerprint of the bytecode --target names *)
  fun fingerprint () : int = if !CompilerSettings.target = "registers" then RegCodes.fingerprint else Opcodes.fingerprint

  (* A unit, elaborated, made into its code and what the linker needs of it
     (Link.sessionCode), with Pass.whole false; the units after it may call
     its functions by name (Lower.knownBefore). *)
  fun unitOf (decs : Ast.dec list) : Link.sessionCode =
    let
      val lam = Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = LambdaLint.check,
                            size = Lambda.size}
                           Translate.transProgram decs
      val low = lowOf lam
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
     start's environment and fixity. *)
  fun unitThrough {start : UnitBasis.start, name : string, file : string, text : unit -> string, mode : Source.mode,
                   decs : Ast.dec list, delta : Env.env, fixity : Fixity.env, used : string list}
      : {code : Link.unitCode, exported : UnitBasis.exported, loaded : UnitBasis.result} =
    let
      val timed = Pass.timed
      val sc = timed "unit-passes" (fn () => unitOf decs)
      val x = timed "unit-export" (fn () => UnitBasis.export {start = start, name = name, file = file, text = text, mode = mode,
                                                             delta = delta, fixity = fixity, used = used})
      val () = timed "unit-undo" (fn () => UnitBasis.undo start)
      val l = timed "unit-load" (fn () => UnitBasis.loadKnown ({pickle = #pickle x, file = file, at = #counters start,
                                                               env = #env start, fixity = #fixity start, text = text},
                                                              SOME (#identity x), []))
    in {code = timed "unit-relative" (fn () => UnitBasis.relative (x, sc)), exported = x, loaded = l} end
end
