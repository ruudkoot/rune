(* What Lower asks of the whole program before it makes any code
   (docs/ir.md, Low): how each variable is used, and which functions return
   in globals (results, an optional pass of its own name): an analysis of
   Mid, which changes nothing of it, and the facts that LowLint.results
   checks what Lower made of them against (Pipeline.lowered). *)
structure Results =
struct
  structure M = Mid
  structure L = Low

  fun bug msg = Error.bug ("Results: " ^ msg)

  val useCounts : int IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.useCounts", useCounts, IntTable.copy)

  (* How many uses of each variable take a field of it (Select) in the
     function it is bound in: where that is all its uses, the argument of a
     constructor made of its fields is never made whole (Rep, M11). *)
  val selectUses : int IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.selectUses", selectUses, IntTable.copy)
  val binderFn : int IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.binderFn", binderFn, IntTable.copy)
  val nextFn = ref 0
  val () = CompilerState.cellRoot ("Results.nextFn", nextFn)
  val () = Pass.counter nextFn
  (* and the fields each takes (results in globals, below) *)
  val selectFields : int list IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.selectFields", selectFields, IntTable.copy)
  (* and, of a variable bound to a call, the uses that only ask its
     constructor or take its argument: ConTag, Decon, ptr_eq with a nullary
     constructor (datatypes returned in globals, below) *)
  val sumUses : int IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.sumUses", sumUses, IntTable.copy)
  (* and how many of its globals the deconstructions of it read *)
  val sumRead : int IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.sumRead", sumRead, IntTable.copy)
  fun countSelects (e : M.exp) : unit =
    let
      val f = !nextFn
      val () = nextFn := f + 1
      (* binderFn: the function's number, twice, and one more for a
         variable bound to a call, whose fields are kept too *)
      fun sel r =
        case r of
          M.Select (i, M.Var (y, _)) =>
            (case IntTable.find (!binderFn, y) of
               SOME k =>
                 if k div 2 <> f then ()
                 else
                   (IntTable.bump (!selectUses, y);
                    if k mod 2 = 0 then ()
                    else
                      case IntTable.find (!selectFields, y) of
                        SOME is => if List.exists (fn j => j = i) is then () else IntTable.insert (!selectFields, y, i :: is)
                      | NONE => IntTable.insert (!selectFields, y, [i]))
             | NONE => ())
        | M.ConTag (M.Var (y, _)) => sum y
        | M.Decon (tag, t, M.Var (y, _)) =>
            (sum y;
             let val n = case Rep.fields (t, tag) of SOME n => n | NONE => 1
             in case IntTable.find (!sumRead, y) of
                  SOME m => if m >= n then () else IntTable.insert (!sumRead, y, n)
                | NONE => IntTable.insert (!sumRead, y, n)
             end)
        | M.Prim ("ptr_eq", _, [M.Var (y, _), M.Con0 _]) => sum y
        | M.Prim ("ptr_eq", _, [M.Con0 _, M.Var (y, _)]) => sum y
        | _ => ()
      and sum y =
        case IntTable.find (!binderFn, y) of
          SOME k => if k = 2 * f + 1 then IntTable.bump (!sumUses, y) else ()
        | NONE => ()
      fun go e =
        case e of
          M.Let (x, _, r, b) =>
            (sel r; IntTable.insert (!binderFn, x, 2 * f + (case r of M.App _ => 1 | _ => 0)); go b)
        | M.Fun (fs, b) => (List.app (countSelects o #body) fs; go b)
        | M.Join (_, _, jb, sc) => (go jb; go sc)
        | M.If (_, t, e) => (go t; go e)
        | M.Handle (a, _, h) => (go a; go h)
        | M.Return r => sel r
        | M.Mark (_, a) => go a
        (* a test of a tag, as its ConTag *)
        | M.Case (a, arms, d) => ((case a of M.Var (y, _) => sum y | _ => ()); List.app go (M.caseExps (arms, d)))
        | M.Jump _ => ()
        | M.Raise _ => ()
    in go e end
  fun selectsOf x = case IntTable.find (!selectUses, x) of SOME n => n | NONE => 0

  fun count x = IntTable.bump (!useCounts, x)
  fun usesOf x = case IntTable.find (!useCounts, x) of SOME n => n | NONE => 0

  fun countAtom a = case a of M.Var (x, _) => count x | _ => ()
  fun countRhs r = M.appAtomsOfRhs countAtom r

  fun countExp e =
    case e of
      M.Let (_, _, r, b) => (countRhs r; countExp b)
    | M.Fun (fs, b) => (List.app (countExp o #body) fs; countExp b)
    | M.Join (_, _, body, s) => (countExp body; countExp s)
    | M.Jump (_, xs) => List.app countAtom xs
    | M.If (c, t, f) => (countAtom c; countExp t; countExp f)
    | M.Handle (a, _, h) => (countExp a; countExp h)
    | M.Raise a => countAtom a
    | M.Return r => countRhs r
    | M.Mark (_, a) => countExp a
    | M.Case (a, arms, d) => (countAtom a; List.app countExp (M.caseExps (arms, d)))

  (* ---- results in globals (performance M8, D8 A, step 2) ---- *)

  (* A function of the top level that returns a tuple of n fields, each of
     its returns one made there (Return (Tuple xs)) or a tail call of
     another such function of n, and that is only called -- never used as a
     value -- returns the first field and leaves the others in globals, the
     same n - 1 for every such function of n results, which a call reads at
     once: the tuple is not made, where the caller only takes its fields.
     An optional pass of its own name ("results", from -O1), for the whole
     program only (Pass.whole: a unit after this one would call it the
     usual way), and not where the debugger reads the program (-g), whose
     stops could come between a return and the reads. *)
  val resultsOn = ref false
  val () = CompilerState.cellRoot ("Results.resultsOn", resultsOn)
  val slotFuns : int IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Results.slotFuns", slotFuns)
  val slotGlobals : int list IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Results.slotGlobals", slotGlobals)
  (* the fields of n results some call reads: the others are not set *)
  val slotNeeded : int list IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Results.slotNeeded", slotNeeded)
  fun needed (n : int, i : int) : bool =
    case IntMap.find (!slotNeeded, n) of SOME is => List.exists (fn j => j = i) is | NONE => false
  (* the fields a call's result has taken, where it is only taken apart *)
  fun takenOnly (x : int) : int list option =
    if usesOf x = selectsOf x then SOME (case IntTable.find (!selectFields, x) of SOME is => is | NONE => []) else NONE
  (* the n of the function being made, where it returns so *)
  val currentSlots : int option ref = ref NONE
  val () = CompilerState.cellRoot ("Results.currentSlots", currentSlots)

  (* The same for a datatype (performance M8): a function each of whose
     returns is a constructor made there, or a tail call of another such
     function of its datatype, every call of which only asks the
     constructor and takes its argument, returns the constructor's tag as a
     nullary constructor's, and the argument in globals -- the fields of a
     constructor made of its fields, each in one -- as many as the
     datatype's widest constructor has, the same for every function of the
     datatype. A call reads all of them at once, of any representation,
     since they may hold what an earlier return left; they are set to ()
     when the program starts, so that none is read unset. *)
  val sumFuns : int IntMap.map ref = ref IntMap.empty            (* the function's global -> its datatype *)
  val () = CompilerState.cellRoot ("Results.sumFuns", sumFuns)
  val sumGlobals : int list IntMap.map ref = ref IntMap.empty    (* the datatype -> its globals *)
  val () = CompilerState.cellRoot ("Results.sumGlobals", sumGlobals)
  val currentSum : int option ref = ref NONE
  val () = CompilerState.cellRoot ("Results.currentSum", currentSum)

  fun sumWidth (t : Ty.ty) : int option =
    case Ty.view t of
      Ty.Con (stamp, _, _) =>
        (case Ty.datatypeOf stamp of
           SOME {cons, ...} =>
             if List.exists (fn (_, _, a) => isSome a) cons then
               SOME (List.foldl (fn ((tag, _, SOME _), w) => Int.max (w, case Rep.fields (t, tag) of SOME n => n | NONE => 1)
                                  | (_, w) => w) 0 cons)
             else NONE
         | NONE => NONE)
    | _ => NONE

  fun sumsOf (stamp : int) : int list = case IntMap.find (!sumGlobals, stamp) of SOME gs => gs | NONE => []

  fun takenSum (x : int) : bool =
    usesOf x = (case IntTable.find (!sumUses, x) of SOME n => n | NONE => 0)

  fun slotsOf (n : int) : int list =
    case IntMap.find (!slotGlobals, n) of
      SOME gs => gs
    | NONE =>
        let val gs = List.tabulate (n - 1, fn _ => Stamp.fresh ())
        in slotGlobals := IntMap.insert (!slotGlobals, n, gs); gs end

  fun slotCall (r : M.rhs) : (int * int * M.atom list) option =
    case r of
      M.App (M.Global (g, _), xs) => Option.map (fn n => (g, n, xs)) (IntMap.find (!slotFuns, g))
    | _ => NONE

  (* The most uses of x on any way through e that need it whole, not a
     field of it: where that is one, a tuple returned in globals is made
     where it is needed, after the call, as rarely as it was before. *)
  fun wholeOnEachPath (x : int, e : M.exp) : int =
    let
      fun a (M.Var (y, _)) = if y = x then 1 else 0
        | a _ = 0
      fun atoms xs = List.foldl (fn (v, n) => n + a v) 0 xs
      fun rhs r =
        case r of
          M.Select (_, M.Var _) => 0
        | _ => M.foldAtomsOfRhs (fn (v, n) => n + a v) 0 r
      fun mentions e = go e > 0
      and go e =
        case e of
          M.Let (_, _, r, b) => rhs r + go b
        | M.Fun (fs, b) => List.foldl (fn (f, n) => n + (if mentions (#body f) then 1 else 0)) 0 fs + go b
        | M.Join (_, _, jb, sc) => go sc + go jb
        | M.Jump (_, xs) => atoms xs
        | M.If (c, t, f) => a c + Int.max (go t, go f)
        | M.Handle (h, _, k) => go h + go k
        | M.Raise v => a v
        | M.Return r => rhs r
        | M.Mark (_, b) => go b
        | M.Case (v, arms, d) => a v + List.foldl (fn (e, m) => Int.max (go e, m)) 0 (M.caseExps (arms, d))
    in go e end

  (* the calls whose tuple is made where it is needed (above) *)
  val lazyCalls : unit IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Results.lazyCalls", lazyCalls, IntTable.copy)

  fun findSumFuns (p : M.program, asValue : unit IntTable.table) : unit =
    let
      (* the candidates: functions of a datatype with a constructor of an
         argument, never used as a value, nor returning a tuple in globals *)
      val cands : (int * int) IntTable.table = IntTable.table 256    (* the function -> its datatype, its width *)
      val () =
        List.app (fn M.Funs fs =>
                       List.app (fn f =>
                                   case (Ty.view (#result f), IntTable.find (asValue, #name f), IntMap.member (!slotFuns, #name f)) of
                                     (Ty.Con (stamp, _, _), NONE, false) =>
                                       (case sumWidth (#result f) of
                                          SOME w => IntTable.insert (cands, #name f, (stamp, w))
                                        | NONE => ())
                                   | _ => ()) fs
                   | _ => ()) p
      fun stampOf g = Option.map #1 (IntTable.find (cands, g))
      (* one walk of the program: the candidates that cannot be, and which
         candidate's returns are another's tail calls (both ways) *)
      val bad : unit IntTable.table = IntTable.table 256
      val tails : int list IntTable.table = IntTable.table 256       (* g -> the candidates whose tail calls call it *)
      val tailsOf : int list IntTable.table = IntTable.table 256     (* f -> the candidates it tail calls *)
      fun push (t, k, v) = IntTable.insert (t, k, v :: (case IntTable.find (t, k) of SOME vs => vs | NONE => []))
      fun no g = IntTable.insert (bad, g, ())
      fun visit (own : int option) e =
        case e of
          M.Let (x, _, M.App (M.Global (g, _), _), b) =>
            ((if isSome (stampOf g) andalso not (takenSum x) then no g else ()); visit own b)
        | M.Let (_, _, _, b) => visit own b
        | M.Fun (fs, b) => (List.app (fn f => visit NONE (#body f)) fs; visit own b)
        | M.Join (_, _, jb, sc) => (visit own jb; visit own sc)
        | M.If (_, a, c) => (visit own a; visit own c)
        | M.Handle (a, _, h) => (visit own a; visit own h)
        | M.Return r =>
            (case (own, r) of
               (SOME f, M.Con _) => ()
             | (SOME f, M.Atom (M.Con0 _)) => ()
             | (SOME f, M.App (M.Global (g, _), _)) =>
                 if isSome (stampOf g) andalso stampOf g = stampOf f then (push (tails, g, f); push (tailsOf, f, g))
                 else (no f; if isSome (stampOf g) then no g else ())
             | (SOME f, _) => no f
             | (NONE, M.App (M.Global (g, _), _)) => if isSome (stampOf g) then no g else ()
             | (NONE, _) => ())
        | M.Mark (_, a) => visit own a
        | M.Case (_, arms, d) => List.app (visit own) (M.caseExps (arms, d))
        | M.Jump _ => ()
        | M.Raise _ => ()
      val () =
        List.app (fn M.Val (_, _, e) => visit NONE e
                   | M.Funs fs => List.app (fn f => visit (if isSome (stampOf (#name f)) then SOME (#name f) else NONE) (#body f)) fs
                   | M.Do (_, e) => visit NONE e) p
      (* a candidate that cannot be makes none of those it tail calls, nor
         of those that tail call it *)
      fun spread [] = ()
        | spread (g :: rest) =
            let
              val next = (case IntTable.find (tails, g) of SOME fs => fs | NONE => [])
                         @ (case IntTable.find (tailsOf, g) of SOME hs => hs | NONE => [])
              val fresh = List.filter (fn h => not (isSome (IntTable.find (bad, h)))) next
            in
              List.app no fresh; spread (fresh @ rest)
            end
      val badNow = ref []
      val () = List.app (fn M.Funs fs => List.app (fn f => if isSome (IntTable.find (bad, #name f)) then badNow := #name f :: !badNow else ()) fs
                          | _ => ()) p
      val () = spread (!badNow)
      val found =
        List.foldl (fn (M.Funs fs, acc) =>
                         List.foldl (fn (f, acc) =>
                                       case IntTable.find (cands, #name f) of
                                         SOME (stamp, w) => if isSome (IntTable.find (bad, #name f)) then acc else (#name f, stamp, w) :: acc
                                       | NONE => acc) acc fs
                     | (_, acc) => acc) [] p
    in
      sumFuns := List.foldl (fn ((g, stamp, _), m) => IntMap.insert (m, g, stamp)) IntMap.empty found;
      sumGlobals :=
        List.foldl (fn ((_, stamp, w), m) =>
                      if IntMap.member (m, stamp) then m
                      else IntMap.insert (m, stamp, List.tabulate (w, fn _ => Stamp.fresh ()))) IntMap.empty (List.rev found)
    end

  fun findSlotFuns (p : M.program) : unit =
    let
      (* the candidates, each with its n *)
      val cands0 =
        List.foldl (fn (M.Funs fs, m) =>
                         List.foldl (fn (f, m) =>
                                       case Ty.view (#result f) of
                                         Ty.Tuple (ts as _ :: _ :: _) => IntMap.insert (m, #name f, (List.length ts, #body f))
                                       | _ => m) m fs
                     | (_, m) => m) IntMap.empty p
      (* the globals used other than as the function a call calls *)
      val asValue : unit IntTable.table = IntTable.table 256
      fun atom a = case a of M.Global (g, _) => IntTable.insert (asValue, g, ()) | _ => ()
      fun rhs r =
        case r of
          M.App (M.Global _, xs) => List.app atom xs
        | _ => M.appAtomsOfRhs atom r
      fun exp e =
        case e of
          M.Let (_, _, r, b) => (rhs r; exp b)
        | M.Fun (fs, b) => (List.app (exp o #body) fs; exp b)
        | M.Join (_, _, jb, sc) => (exp jb; exp sc)
        | M.Jump (_, xs) => List.app atom xs
        | M.If (a, t, f) => (atom a; exp t; exp f)
        | M.Handle (a, _, h) => (exp a; exp h)
        | M.Raise a => atom a
        | M.Return r => rhs r
        | M.Mark (_, a) => exp a
        | M.Case (a, arms, d) => (atom a; List.app exp (M.caseExps (arms, d)))
      val () = List.app (fn M.Val (_, _, e) => exp e | M.Funs fs => List.app (exp o #body) fs | M.Do (_, e) => exp e) p
      val cands1 = IntMap.filteri (fn (g, _) => not (isSome (IntTable.find (asValue, g)))) cands0
      (* whether every return of a function's own code is a tuple of n
         made there, or a tail call of a candidate of n *)
      fun returns (cands, n) e =
        case e of
          M.Let (_, _, _, b) => returns (cands, n) b
        | M.Fun (_, b) => returns (cands, n) b
        | M.Join (_, _, jb, sc) => returns (cands, n) jb andalso returns (cands, n) sc
        | M.If (_, t, f) => returns (cands, n) t andalso returns (cands, n) f
        | M.Handle (a, _, h) => returns (cands, n) a andalso returns (cands, n) h
        | M.Return (M.Tuple xs) => List.length xs = n
        | M.Return (M.App (M.Global (g, _), _)) =>
            (case IntMap.find (cands, g) of SOME (m, _) => m = n | NONE => false)
        | M.Return _ => false
        | M.Mark (_, a) => returns (cands, n) a
        | M.Case (_, arms, d) => List.all (returns (cands, n)) (M.caseExps (arms, d))
        | M.Jump _ => true
        | M.Raise _ => true
      (* the candidates that cannot be: some call of them needs the tuple
         whole -- its value used other than by taking its fields, or
         returned by a function that does not return as it does -- where
         the tuple would be made after all, and the globals set and read for
         nothing; and, both ways, the candidates one of them tail calls or
         that tail call one of them, which then return otherwise *)
      fun found cands =
        let
          val bad : unit IntTable.table = IntTable.table 64
          fun no g = IntTable.insert (bad, g, ())
          (* of each candidate, the calls and those that need the tuple more
             than once on a way, where it is made at once: a tuple of four
             fields at most, made so by no more than a quarter of its calls,
             else the globals cost more than they save *)
          val calls : (int * int) IntMap.map ref = ref IntMap.empty
          fun count (g, eager) =
            let val (n, e) = case IntMap.find (!calls, g) of SOME c => c | NONE => (0, 0)
            in calls := IntMap.insert (!calls, g, (n + 1, if eager then e + 1 else e)) end
          fun small g = case IntMap.find (cands, g) of SOME (n, _) => n <= 4 | NONE => false
          (* a use of x that needs it whole on each way after it, at most *)
          fun lazy (x, b) = usesOf x - selectsOf x <= 1 orelse wholeOnEachPath (x, b) <= 1
          (* the tail calls between candidates, both ways *)
          val tails : int list IntTable.table = IntTable.table 64
          fun push (k, v) = IntTable.insert (tails, k, v :: (case IntTable.find (tails, k) of SOME vs => vs | NONE => []))
          fun ownOf f = Option.map (fn (n, _) => (f, n)) (IntMap.find (cands, f))
          fun visit (own : (int * int) option) e =
            case e of
              M.Let (x, _, M.App (M.Global (g, _), _), b) =>
                ((if IntMap.member (cands, g) then
                    if isSome (takenOnly x) then count (g, false)
                    else if small g andalso lazy (x, b) then (IntTable.insert (!lazyCalls, x, ()); count (g, false))
                    else if small g then count (g, true)
                    else no g
                  else ());
                 visit own b)
            | M.Let (_, _, _, b) => visit own b
            | M.Fun (fs, b) => (List.app (fn f => visit (ownOf (#name f)) (#body f)) fs; visit own b)
            | M.Join (_, _, jb, sc) => (visit own jb; visit own sc)
            | M.If (_, t, f) => (visit own t; visit own f)
            | M.Handle (a, _, h) => (visit own a; visit own h)
            | M.Return (M.App (M.Global (g, _), _)) =>
                (case (IntMap.find (cands, g), own) of
                   (SOME (n, _), SOME (f, m)) => if m = n then (push (f, g); push (g, f)) else no g
                 | (SOME _, NONE) => no g
                 | (NONE, _) => ())
            | M.Mark (_, a) => visit own a
            | M.Case (_, arms, d) => List.app (visit own) (M.caseExps (arms, d))
            | M.Jump _ => ()
            | M.Raise _ => ()
            | M.Return _ => ()
          val () =
            List.app (fn M.Val (_, _, e) => visit NONE e
                       | M.Funs fs => List.app (fn f => visit (ownOf (#name f)) (#body f)) fs
                       | M.Do (_, e) => visit NONE e) p
          val () = IntMap.appi (fn (g, (n, e)) => if 4 * e > n then no g else ()) (!calls)
          val () = IntMap.appi (fn (g, (n, body)) => if returns (cands, n) body then () else no g) cands
          fun spread [] = ()
            | spread (g :: rest) =
                let val fresh = List.filter (fn h => not (isSome (IntTable.find (bad, h))))
                                            (case IntTable.find (tails, g) of SOME hs => hs | NONE => [])
                in List.app no fresh; spread (fresh @ rest) end
          val () = spread (IntMap.foldli (fn (g, _, acc) => if isSome (IntTable.find (bad, g)) then g :: acc else acc) [] cands)
        in
          IntMap.filteri (fn (g, _) => not (isSome (IntTable.find (bad, g)))) cands
        end
      val () = slotFuns := (if !resultsOn then IntMap.map #1 (found cands1) else IntMap.empty)
      (* what each call reads: the fields it takes, where it only takes
         them, all of them where it needs the tuple, none where it passes
         them on (a tail call of one of n from one of n) *)
      fun need (n, is) =
        let val old = case IntMap.find (!slotNeeded, n) of SOME js => js | NONE => []
        in slotNeeded := IntMap.insert (!slotNeeded, n, List.foldl (fn (i, acc) => if List.exists (fn j => j = i) acc then acc else i :: acc) old is) end
      fun all n = List.tabulate (n, fn i => i)
      fun callIn (own : int option) e =
        case e of
          M.Let (x, _, M.App (M.Global (g, _), _), b) =>
            ((case IntMap.find (!slotFuns, g) of
                SOME n => need (n, case takenOnly x of SOME is => is | NONE => all n)
              | NONE => ());
             callIn own b)
        | M.Let (_, _, _, b) => callIn own b
        | M.Fun (fs, b) => (List.app (fn f => callIn (IntMap.find (!slotFuns, #name f)) (#body f)) fs; callIn own b)
        | M.Join (_, _, jb, sc) => (callIn own jb; callIn own sc)
        | M.If (_, t, f) => (callIn own t; callIn own f)
        | M.Handle (a, _, h) => (callIn own a; callIn own h)
        | M.Return (M.App (M.Global (g, _), _)) =>
            (case IntMap.find (!slotFuns, g) of
               SOME n => if own = SOME n then () else need (n, all n)
             | NONE => ())
        | M.Mark (_, a) => callIn own a
        | M.Case (_, arms, d) => List.app (callIn own) (M.caseExps (arms, d))
        | M.Jump _ => ()
        | M.Raise _ => ()
        | M.Return _ => ()
    in
      sumFuns := IntMap.empty; sumGlobals := IntMap.empty;
      if !resultsOn then findSumFuns (p, asValue) else ();
      slotNeeded := IntMap.empty;
      List.app (fn M.Val (_, _, e) => callIn NONE e
                 | M.Funs fs => List.app (fn f => callIn (IntMap.find (!slotFuns, #name f)) (#body f)) fs
                 | M.Do (_, e) => callIn NONE e) p
    end

end
