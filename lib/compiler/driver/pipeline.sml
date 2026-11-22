(* The stages of the compiler from Lambda on, which the batch driver (Main)
   and the resident compiler of the REPL (src/repl) share: Mid, the optional
   passes on it with Rune's own (Expand) first, then what MidPipeline does
   from Mid on; and a unit's code with what the linker needs of it
   (docs/units.md). *)
structure Pipeline =
struct
  open MidPipeline

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

  (* a unit's Mid as ToMid made it, with what it needs of the tables, kept
     where a whole program is to be made of its units' (--whole; the
     incremental roadmap's M7) *)
  val keepMid = ref false
  val () = CompilerState.cellRoot ("Pipeline.keepMid", keepMid)
  val lastMid : MidCanon.unitMid option ref = ref NONE
  val () = CompilerState.cellRoot ("Pipeline.lastMid", lastMid)

  (* What a compile of Rune runs on Mid: Expand first, which gives the
     copies of applications back before anything else is done to them (in a
     build in units, of the unit's own functors and those marked to be
     inlined), then the passes of any front end (MidPipeline). A client of
     the compiler changes this list before it compiles. *)
  val midPasses : midPass list ref =
    ref (pass ("expand", fn m => (Expand.knownFunction := (fn g => IntMap.member (!Lower.knownBefore, g));
                                  Expand.program m))
         :: standardPasses)
  val () = CompilerState.cellRoot ("Pipeline.midPasses", midPasses)
  fun passNames () : string list = MidPipeline.passNames (!midPasses)
  fun removePass (name : string) : unit = midPasses := MidPipeline.removePass name (!midPasses)
  fun insertBefore (name : string, p : midPass) : unit = midPasses := MidPipeline.insertBefore (name, p) (!midPasses)
  fun insertAfter (name : string, p : midPass) : unit = midPasses := MidPipeline.insertAfter (name, p) (!midPasses)
  fun replacePass (name : string, p : midPass) : unit = midPasses := MidPipeline.replacePass (name, p) (!midPasses)

  (* What a stage of Rune's does inside it, by the names --passes and the
     levels go by: `trees`, how translate compiles a match, which MatchComp
     asks of Pass itself, and the parts of the stages from Mid on *)
  val parts : (string * string * int) list = ("translate", "trees", 1) :: MidPipeline.parts
  (* The names --passes may give, and the stages from Lambda to the
     target's code, which --dump-before and --dump-after may give *)
  fun optionalNames () : string list = distinct (passNames () @ List.map #2 parts)
  fun stageNames () : string list = "translate" :: MidPipeline.stageNames (!midPasses)

  fun lowOfMid (mid : Mid.program) : Low.program = MidPipeline.lowOfMid (!midPasses) mid

  (* Lambda to Low: Mid, the optional passes on it, and Lower *)
  fun lowOf (lam : Lambda.lexp) : Low.program =
    let
      val mid = midStage (SOME Lambda.show) ToMid.program lam
      val () = if not (!Pass.whole) andalso !keepMid then lastMid := SOME (MidCanon.capture mid) else ()
      (* the marked functors' functions, for the unit's basis *)
      val () = if not (!Pass.whole) then Expand.keepMarked mid else ()
    in lowOfMid mid end

  (* A unit, elaborated, made into its code and what the linker needs of it
     (Link.sessionCode), with Pass.whole false; the units after it may call
     its functions by name (Lower.knownBefore). *)
  fun unitOf (decs : Ast.dec list) : Link.sessionCode =
    let
      val lam = Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = Pass.checkAt ("translate", 1) LambdaLint.check,
                            size = Lambda.size}
                           (fn decs => Fault.lambda ("translate", Translate.transProgram decs)) decs
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
      (* the functions it declares that are marked to be inlined, whose Mid
         its basis keeps (functors-units M10) *)
      val () = Elaborate.markValues delta
      val () = (Expand.declaredOrder := []; Expand.declaredSchemes := [])
      val sc = timed "unit-passes" (fn () => unitOf decs)
      val x = timed "unit-export" (fn () => UnitBasis.export {start = start, name = name, file = file, text = text, mode = mode,
                                                             delta = delta, fixity = fixity})
      val () = timed "unit-undo" (fn () => UnitBasis.undo start)
      val l = timed "unit-load" (fn () => UnitBasis.loadKnown ({pickle = #pickle x, sidecar = #sidecar x, file = file, at = #counters start},
                                                              SOME (if fresh then UnitBasis.unused (#identity x)
                                                                    else #identity x), []))
      (* what it loads as written again is the same bytes *)
      val () = Pass.checkAt ("basis-rt", 2) (UnitBasis.sameAgain ({start = start, name = name, file = file, mode = mode}, l)) (#pickle x)
    in {code = timed "unit-relative" (fn () => UnitBasis.relative (x, sc)), exported = x, loaded = l} end)
end
