(* The stages of the compiler from Lambda on, which the batch driver (Main)
   and the resident compiler of the REPL (src/repl) share: Mid, the optional
   passes on it, Lower, the target of --target; and a unit's code with what
   the linker needs of it (docs/units.md). *)
structure Pipeline =
struct
  (* The stage that makes Mid, from Lambda or from its text. *)
  fun midStage (showIn : ('a -> string) option) (f : 'a -> Mid.program) : 'a -> Mid.program =
    Pass.stage {name = "mid", showIn = showIn, show = MidText.show,
                check = fn p => (MidLint.check p; if !Options.midRoundTrip then MidText.roundTrip p else ()),
                size = Mid.size}
               f

  (* Lambda to Low: Mid, the optional passes on it, and Lower. Shake runs
     on a whole program only (Pass.whole). *)
  fun lowOf (lam : Lambda.lexp) : Low.program =
    let
      val mid = midStage (SOME Lambda.show) ToMid.program lam
      (* the optional passes on Mid (docs/ir.md) *)
      fun optional (name, f) m =
        if Pass.enabled (name, 1) andalso (name <> "shake" orelse !Pass.whole) then
          Pass.stage {name = name, showIn = SOME MidText.show, show = MidText.show, check = MidLint.check,
                      size = Mid.size}
                     f m
        else m
      val mid = optional ("shake", Shake.program) mid
      val mid = optional ("lift", Lift.program) mid
      val mid = optional ("workers", Workers.program) mid
      val mid = optional ("simplify", Simplify.program) mid
      (* what the inliner left of the functions it put in place goes *)
      val mid =
        if Pass.enabled ("simplify", 1) andalso Pass.enabled ("inline", 1) then optional ("shake", Shake.program) mid
        else mid
    in
      Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show, check = LowLint.check,
                  size = Low.size}
                 (fn m => Lower.program (m, !Translate.funNames)) mid
    end

  (* Low to the code of the target --target names *)
  fun targetStage (low : Low.program) : Code.program =
    if !Options.target = "registers" then
      Pass.stage {name = "registers", showIn = SOME Low.show, show = Code.dump, check = fn _ => (), size = Code.size}
                 Regs.program low
    else
      Pass.stage {name = "stack", showIn = SOME Low.show, show = Code.dump, check = fn _ => (), size = Code.size}
                 Stack.program low

  (* the fingerprint of the bytecode --target names *)
  fun fingerprint () : int = if !Options.target = "registers" then RegCodes.fingerprint else Opcodes.fingerprint

  (* A unit, elaborated, made into its code and what the linker needs of it
     (Link.unitCode), with Pass.whole false; the units after it may call its
     functions by name (Lower.knownBefore). *)
  fun unitOf (decs : Ast.dec list) : Link.unitCode =
    let
      val lam = Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = LambdaLint.check,
                            size = Lambda.size}
                           Translate.transProgram decs
      val low = lowOf lam
      val code = targetStage low
      val u : Link.unitCode =
        {code = code, globals = IntMap.listItemsi (!Code.globals), defines = Link.defines low,
         imports = List.map (fn (s, i) => (i, s)) (IntMap.listItemsi (!Lower.imported)),
         exports = IntMap.listItemsi (!Lower.globalFids)}
    in
      Lower.knownBefore := IntMap.foldli (fn (s, _, m) => IntMap.insert (m, s, ())) (!Lower.knownBefore)
                                         (!Lower.globalFids);
      u
    end
end
