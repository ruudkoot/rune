(* A check of the register code (src/isa/regs.sml): the code Regs makes, the
   program Link makes of units, and the units UnitFile reads back
   (docs/plans/correctness/linting.md, M8; D8-D10). It finds the bugs of
   Regs and Link that the VM's loader lets through and the JIT's tier 2
   would trust (docs/plans/correctness/linting.md, E7): it checks what the
   compiler says of the code, not that the code is safe, since a value read
   from the heap or a polymorphic function is of any representation and
   the compiler's types alone say what it is (a downcast, trusted and
   counted).

   What each instruction reads, writes, leaves and takes, what must come
   after it and which primitives it names are RegCodes' tables, generated
   from src/isa; what the program declares -- each register's
   representation, each function's arity, result and captures, each
   global's representation -- is the code's meta (Code.meta, from Lower).
   The dataflow is this, one forward pass over each function's items:
   * each register holds a representation (Low.repCode) under the order
     x <= x, x <= any, con0 <= con, ptr <= con, or is unset. A write of m
     into a register declared q is right where m <= q, a downcast where
     q < m, and a breach otherwise; a read that wants q of a register
     holding m the same, and a breach where it is unset;
   * at the entry, the parameters are set and nothing else; the scratch,
     the last register, holds nothing at a label;
   * a label's state is the meet of the ways into it, which go forward but
     a jump back to a loop head (meta.loops), whose registers are then what
     they are declared, as at a handler's block; a jump back sets every
     register the head has set; the handlers pushed are as many on every
     way in, and none where the frame is left;
   * a fact of a register's value: its constructor's tag (a constructor
     made, a tag tested), another tag than one, or a closure of a function.
     A tag test a fact answers leaves the other way untaken; FIELD and
     DECON of another tag than a fact says are breaches;
   * a known call passes the callee's parameters, a closure is of a
     function of one parameter and captures what each of its closures
     captures, ENV and SELF are only in a function closures are made of and
     no known call calls, a primitive's arguments and result are what its
     type says (Prims.repsOf).

   It runs from level 1 of the lint, the boundaries, by its cost (docs/ir.md,
   Levels: the compiler's compile 4.4% more, HaMLet's 1.6%, MLton's 0.8%),
   through Pass.checkAt, after the stage `registers` (stage, key regverify)
   and on every program Link makes (linked, key regverify-link);
   RUNE_REGVERIFY=1 runs it at every level, 0 at none, and census prints
   its counts.
   RUNE_REGVERIFY_INJECT corrupts the code Regs made, for its negative
   tests (inject). *)
structure RegVerify =
struct
  structure C = Code
  structure R = RegCodes

  fun i2s n = Int.toString n

  (* ---- representations ---- *)

  val UNSET = ~1
  val ANY = 0
  val RINT = 1
  val RWORD = 2
  val RREAL = 3
  val RCHAR = 4
  val RCON0 = 5
  val RPTR = 6
  val RCON = 7
  val RUNIT = 8
  val RINT64 = 9
  val RWORD64 = 10

  fun repName r = if r = UNSET then "unset" else Low.repName (Low.repOfCode r)

  fun le (a, b) = a = b orelse b = ANY orelse (b = RCON andalso (a = RCON0 orelse a = RPTR))
  fun conish a = a = RCON0 orelse a = RPTR orelse a = RCON
  fun lub (a, b) =
    if le (a, b) then b else if le (b, a) then a else if conish a andalso conish b then RCON else ANY

  (* A register's cell: its representation, or UNSET, and a fact of its
     value, in one int: (rep + 1) + 16 * fact. A fact is 0, none; 1 + t, a
     constructor of tag t; notBase + t, one of another tag than t; closBase
     + i, a closure of the function of index i. *)
  val notBase = 65537
  val closBase = 131074
  fun cRep x = x mod 16 - 1
  fun cFact x = x div 16
  fun cell (r, fact) = r + 1 + 16 * fact
  val cUnset = 0

  (* ---- the switch ---- *)

  fun setting () = case OS.Process.getEnv "RUNE_REGVERIFY" of SOME s => s | NONE => ""
  (* the level of lint it runs from: 1, unless RUNE_REGVERIFY says always
     (any level, off too) or never *)
  fun level () = case setting () of "" => SOME 1 | "0" => NONE | _ => SOME Pass.off

  (* ---- the primitives, by number ---- *)

  val primTables : (string vector * int vector * int vector vector * int vector * bool vector) option ref = ref NONE
  val () = CompilerState.cellRoot ("RegVerify.primTables", primTables)
  fun prims () =
    case !primTables of
      SOME t => t
    | NONE =>
        let
          val n = List.foldl (fn ((_, i, _), m) => Int.max (m, i + 1)) 0 Prims.table
          val names = Array.array (n, "")
          val arities = Array.array (n, ~1)
          val () = List.app (fn (s, i, a) => (Array.update (names, i, s); Array.update (arities, i, a))) Prims.table
          val names = Array.vector names
          val rs = Vector.tabulate (n, fn i => case Prims.repsAt i of SOME (a, r) => (Vector.fromList a, r) | NONE => (Vector.fromList [], ANY))
          val image = Array.array (n, false)
          val () = List.app (fn s => case Prims.find s of SOME (i, _) => Array.update (image, i, true) | NONE => ()) R.imagePrims
          val t = (names, Array.vector arities, Vector.map #1 rs, Vector.map #2 rs, Array.vector image)
        in primTables := SOME t; t end

  (* ---- what the tables say of each opcode, worked out once ---- *)

  (* its operands before its list, and what each is to it; the position of
     the operand that says how long its list is (~1: none), whether that
     names a primitive, and what each register of the list holds; the
     positions of its label, its primitive, the function it calls known or
     makes a closure of, the tag of a constructor it makes, the count of the
     table after it (~1: none); whether it takes what the one before left,
     reads the running closure, names only image primitives (1) or none
     (0, ~1: either); what it leaves, for which opcode (~1: none); what a
     handler it installs begins with (~1: none); where control goes; what it
     does to the handlers *)
  type opinfo = {nfixed : int, roles : R.role list, listAt : int, listPrim : bool, listHolds : R.value option,
                 label : int, prim : int, known : int, closes : int, tag : int, table : int,
                 takes : bool, readsClosure : bool, image : int,
                 leavesFor : int, leaves : R.value, begins : int, flow : R.flow, handlers : R.handlers,
                 rd : (int * R.value) list, wr : (int * R.value) list, simple : bool}
  val opInfos : opinfo vector option ref = ref NONE
  val () = CompilerState.cellRoot ("RegVerify.opInfos", opInfos)
  fun opInfo () : opinfo vector =
    case !opInfos of
      SOME v => v
    | NONE =>
        let
          fun one opc : opinfo =
            let
              val kinds = Vector.sub (R.operandKinds, opc)
              fun find (_, []) = ~1
                | find (k, x :: rest) = if x = R.kindLabel orelse x = R.kindHandlerLabel then k else find (k + 1, rest)
              val implicit = Vector.sub (R.implicit, opc)
              val order = Vector.sub (R.order, opc)
              val leavesV = List.foldl (fn (R.Leaves v, _) => SOME v | (_, acc) => acc) NONE implicit
              val thenOp = List.foldl (fn (R.Then x, _) => x | (_, acc) => acc) ~1 order
              val roles = Vector.sub (R.roles, opc)
              fun pick f = List.rev (#2 (List.foldl (fn (r, (k, acc)) => (k + 1, case f r of SOME v => (k, v) :: acc | NONE => acc))
                                                    (0, []) roles))
              val rd = pick (fn R.Reads v => SOME v | _ => NONE)
              val wr = pick (fn R.Writes v => SOME v | _ => NONE)
              val tag = if opc = R.CON0 orelse opc = R.CON orelse opc = R.CONN then 1 else ~1
            in
              {nfixed = List.length kinds, roles = Vector.sub (R.roles, opc), listAt = Vector.sub (R.listAt, opc),
               listPrim = Vector.sub (R.listPrim, opc), listHolds = Vector.sub (R.listHolds, opc),
               label = find (0, kinds),
               prim = case Vector.sub (R.listHolds, opc) of SOME (R.ArgsOf k) => k | _ => ~1,
               known = List.foldl (fn (R.CallsKnown k, _) => k | (_, acc) => acc) ~1 implicit,
               closes = List.foldl (fn (R.MakesClosure k, _) => k | (_, acc) => acc) ~1 implicit,
               (* the facts it makes, by hand: a constructor's tag *)
               tag = tag,
               table = List.foldl (fn (R.Table (k, _), _) => k | (_, acc) => acc) ~1 order,
               takes = List.exists (fn R.Takes => true | _ => false) implicit,
               readsClosure = List.exists (fn R.ReadsClosure => true | _ => false) implicit,
               image = case Vector.sub (R.imageOnly, opc) of SOME true => 1 | SOME false => 0 | NONE => ~1,
               leavesFor = case leavesV of SOME _ => thenOp | NONE => ~1,
               leaves = case leavesV of SOME v => v | NONE => R.Is 0,
               begins = List.foldl (fn (R.Begins (_, x), _) => x | (_, acc) => acc) ~1 order,
               flow = Vector.sub (R.flow, opc), handlers = Vector.sub (R.handlers, opc),
               rd = rd, wr = wr,
               (* one that only reads and writes its operands -- making a
                  constructor, taking one apart, reading the closure at
                  most -- and goes on *)
               simple = Vector.sub (R.listAt, opc) < 0
                        andalso List.all (fn R.ReadsClosure => true | _ => false) implicit andalso List.null order
                        andalso Vector.sub (R.imageOnly, opc) = NONE andalso Vector.sub (R.flow, opc) = R.Next
                        andalso Vector.sub (R.handlers, opc) = R.Keeps}
            end
          val v = Vector.tabulate (R.count, one)
        in opInfos := SOME v; v end

  fun nth (x :: _, 0) = x
    | nth (_ :: rest, k) = nth (rest, k - 1)
    | nth ([], _) = ~1
  fun drop (xs, 0) = SOME xs
    | drop (_ :: rest, k) = drop (rest, k - 1)
    | drop ([], _) = NONE

  fun copyCells (a : int array) : int array =
    let
      val n = Array.length a
      val b = Array.array (n, 0)
      fun go i = if i < n then (Array.update (b, i, Array.sub (a, i)); go (i + 1)) else ()
    in go 0; b end

  (* ---- the check of a program ---- *)

  (* mode: "whole", a program whose every function and global is there;
     "unit", a unit's code, whose functions past its own are imports and
     whose globals another unit sets hold anything; "linked" *)
  fun verify (mode : string, p : C.program) : {breaches : int, messages : string list, counts : (string * int) list} =
    let
      val funcs = Vector.fromList (List.filter (fn (f : C.func) => isSome (#meta f)) (#funcs p))
      val nf = Vector.length funcs
      val unitMode = mode = "unit"
      val maxId = Vector.foldl (fn (f : C.func, m) => Int.max (#id f, m)) 0 funcs
      val indexOf = Array.array (maxId + 1, ~1)
      val () = Vector.appi (fn (i, f : C.func) => Array.update (indexOf, #id f, i)) funcs
      fun idx fid = if fid >= 0 andalso fid <= maxId then Array.sub (indexOf, fid) else ~1
      val metas : C.meta vector = Vector.map (fn (f : C.func) => valOf (#meta f)) funcs
      val repsV : int vector vector = Vector.map (fn (m : C.meta) => Vector.fromList (#reps m)) metas
      val captV : int vector vector = Vector.map (fn (m : C.meta) => Vector.fromList (#captures m)) metas
      val arities : int vector = Vector.map #arity metas
      val results : int vector = Vector.map #result metas
      fun arityOf i = Vector.sub (arities, i)
      fun resultOf i = Vector.sub (results, i)
      val consts = Vector.fromList (#consts p)
      val nconsts = Vector.length consts
      val nglobals = #nglobals p
      val greps = case #globalReps p of [] => Vector.tabulate (nglobals, fn _ => ANY) | rs => Vector.fromList rs
      fun globalRep g = if g >= 0 andalso g < Vector.length greps then Vector.sub (greps, g) else ANY
      val (primNames, primArities, primArgs, primRes, primImage) = prims ()
      val infos = opInfo ()
      val nprims = Vector.length primNames
      fun primName pn = if pn >= 0 andalso pn < nprims then Vector.sub (primNames, pn) else "primitive " ^ i2s pn
      fun opName opc = if opc >= 0 andalso opc < R.count then Vector.sub (R.names, opc) else "opcode " ^ i2s opc
      fun constRep k =
        if k < 0 orelse k >= nconsts then ANY
        else case Vector.sub (consts, k) of
               Lambda.CInt _ => RINT | Lambda.CWord _ => RWORD | Lambda.CInt64 _ => RINT64
             | Lambda.CWord64 _ => RWORD64 | Lambda.CReal _ => RREAL | Lambda.CString _ => RPTR
             | Lambda.CChar _ => RCHAR

      (* the labels of the program: the function that has it, where it is
         a handler's what its block begins with, the state of the ways into
         it, the function whose loop head it is, and the state there *)
      val nlabels = Int.max (#nlabels p, 0)
      val labelFn = Array.array (nlabels, ~1)
      val handlerOf = Array.array (nlabels, ~1)
      val pending : (int array * int) option array = Array.array (nlabels, NONE)
      val heads : (int array * int) option array = Array.array (nlabels, NONE)
      val loopOf = Array.array (nlabels, ~1)

      (* what the functions do that a check of another needs: closures made
         of them, known calls of them, their closure read (by what) *)
      val closed = Array.array (nf, false)
      val calledKnown = Array.array (nf, false)
      val readsClosure : string option array = Array.array (nf, NONE)

      (* ---- the counts and the breaches ---- *)
      val nbreach = ref 0
      val msgs : string list ref = ref []
      val ninstr = ref 0
      val downcasts = Array.array (R.count, 0)
      val unchecked = ref 0

      fun func (fi : int) =
        let
          val f = Vector.sub (funcs, fi)
          val {arity, loops, result = declaredResult, ...} = Vector.sub (metas, fi)
          val reps = Vector.sub (repsV, fi)
          val capt = Vector.sub (captV, fi)
          val nl = #nlocals f
          val nl1 = Int.max (nl, 1)
          val scratch = nl - 1
          val pos = ref 0
          (* the instruction being checked, for the message (~1: none) *)
          val curOpc = ref ~1
          val curOps : int list ref = ref []
          fun breach msg =
            (nbreach := !nbreach + 1;
             if !nbreach <= 50
             then msgs := ("function " ^ #name f ^ " (f" ^ i2s (#id f) ^ "), item " ^ i2s (!pos)
                           ^ (if !curOpc < 0 then "" else " (" ^ String.concatWith " " (opName (!curOpc) :: List.map i2s (!curOps)) ^ ")")
                           ^ ": " ^ msg) :: !msgs
             else ())
          val () = if Vector.length reps <> nl then breach ("the meta has " ^ i2s (Vector.length reps) ^ " representations for "
                                                            ^ i2s nl ^ " registers") else ()
          val () = if arity > nl then breach ("arity " ^ i2s arity ^ " in a frame of " ^ i2s nl) else ()
          fun decl r = if r >= 0 andalso r < Vector.length reps then Vector.sub (reps, r) else ANY
          val () = List.app (fn l => if l >= 0 andalso l < nlabels then Array.update (loopOf, l, fi)
                                     else breach ("the loop head L" ^ i2s l ^ " is no label")) loops

          (* the state: the cells, shared with a label's pending state until
             one is written (copied then), and the handlers pushed *)
          val c : int array ref =
            ref (let val a = Array.array (nl1, cUnset)
                     fun go r = if r < arity andalso r < nl1 then (Array.update (a, r, cell (decl r, 0)); go (r + 1)) else ()
                 in go 0; a end)
          val shared = ref false
          fun mine () = (if !shared then (c := copyCells (!c); shared := false) else (); !c)
          fun setCell (r, x) = if r < 0 orelse r >= nl1 then () else Array.update (mine (), r, x)
          val depth = ref 0
          val reach = ref true
          (* what must come next: the opcode the instruction before wants
             (~1: none), what it left, and that instruction *)
          val dueOp = ref ~1
          val dueRep = ref ANY
          val dueFrom = ref ~1
          (* what a handler's block begins with, where it is due *)
          val begins = ref ~1
          (* the JUMPs of a SWITCH's table still due, its subject, the tag
             of the next, and the tag a fact gave the subject *)
          val table = ref 0
          val tableSubject = ref ~1
          val tableTag = ref 0
          val tableKnown = ref ~1
          val forwards : int list ref = ref []

          fun meetCell (x, y) =
            if x = y then x
            else if cRep x = UNSET orelse cRep y = UNSET then cUnset
            else cell (lub (cRep x, cRep y), if cFact x = cFact y then cFact x else 0)
          fun merge (a, b) =
            let
              val n = Int.min (Array.length a, Array.length b)
              fun go i = if i < n then (let val x = Array.sub (a, i) val y = Array.sub (b, i)
                                        in if x = y then () else Array.update (a, i, meetCell (x, y)) end; go (i + 1))
                         else ()
            in go 0 end

          fun okLabel l = l >= 0 andalso l < nlabels
          fun what k = case k of 0 => "branch" | 1 => "jump" | 2 => "handler" | _ => "SWITCH's jump"

          (* an edge to l of kind k (what), with a fact of register s on it
             (s ~1: none) *)
          fun arrive (l, k, s, fact) =
            if not (okLabel l) then breach ("a " ^ what k ^ " to L" ^ i2s l ^ ", which is no label")
            else if Array.sub (labelFn, l) = fi then
              (* back: to a loop head, setting what it set *)
              (if Array.sub (loopOf, l) = fi then () else breach ("a " ^ what k ^ " back to L" ^ i2s l ^ ", which is no loop head of the meta");
               case Array.sub (heads, l) of
                 NONE => breach ("a " ^ what k ^ " back to L" ^ i2s l ^ ", which nothing reached before")
               | SOME (a, d) =>
                   let
                     val cur = !c
                     val n = Int.min (Array.length a, Array.length cur)
                     fun go r = if r < n then
                                  ((if cRep (Array.sub (a, r)) <> UNSET andalso cRep (Array.sub (cur, r)) = UNSET
                                    then breach ("a " ^ what k ^ " back to L" ^ i2s l ^ " without register " ^ i2s r ^ ", which is set there")
                                    else ());
                                   go (r + 1))
                                else ()
                   in
                     if d <> !depth then breach ("a " ^ what k ^ " back to L" ^ i2s l ^ " with " ^ i2s (!depth) ^ " handlers where it has " ^ i2s d) else ();
                     go 0
                   end)
            else if Array.sub (labelFn, l) >= 0 then breach ("a " ^ what k ^ " to L" ^ i2s l ^ ", a label of another function")
            else
              let
                val out =
                  if s < 0 orelse s >= nl1 then !c
                  else let val a = copyCells (!c) in Array.update (a, s, cell (cRep (Array.sub (a, s)), fact)); a end
              in
                case Array.sub (pending, l) of
                  NONE =>
                    (forwards := l :: !forwards;
                     if out = !c then
                       (if !shared then Array.update (pending, l, SOME (copyCells out, !depth))
                        else (Array.update (pending, l, SOME (out, !depth)); shared := true))
                     else Array.update (pending, l, SOME (out, !depth)))
                | SOME (a, d) =>
                    (if d <> !depth then breach ("L" ^ i2s l ^ " is reached with " ^ i2s d ^ " and with " ^ i2s (!depth) ^ " handlers") else ();
                     if a = out then () else merge (a, out))
              end

          fun widen a =
            let
              val n = Array.length a
              fun go r = if r < n then (let val x = Array.sub (a, r)
                                        in if cRep x = UNSET then () else Array.update (a, r, cell (decl r, 0)) end; go (r + 1))
                         else ()
            in go 0 end

          fun label l =
            if not (okLabel l) then breach ("L" ^ i2s l ^ " is no label")
            else
              let
                val fall = !reach
                val handler = Array.sub (handlerOf, l)
                val loop = Array.sub (loopOf, l) = fi
                val () = if Array.sub (labelFn, l) >= 0 then breach ("L" ^ i2s l ^ " is a label twice") else ()
                val () = Array.update (labelFn, l, fi)
                val () = if fall andalso handler >= 0 then breach ("the code falls into the handler's block L" ^ i2s l) else ()
                val () = if !dueOp >= 0
                         then (breach (opName (!dueOp) ^ " is due after " ^ opName (!dueFrom) ^ ", and a label comes"); dueOp := ~1)
                         else ()
                val () = if !table > 0 then (breach "a label in a SWITCH's table"; table := 0) else ()
              in
                (case (fall, Array.sub (pending, l)) of
                   (false, NONE) => reach := false
                 | (true, NONE) => ()
                 | (false, SOME (a, d)) => (c := a; shared := false; depth := d; reach := true)
                 | (true, SOME (a, d)) =>
                     (if d <> !depth then breach ("L" ^ i2s l ^ " is reached with " ^ i2s d ^ " and with " ^ i2s (!depth) ^ " handlers") else ();
                      if a = !c then () else merge (a, !c);
                      c := a; shared := false));
                Array.update (pending, l, NONE);
                if !reach then
                  ((* the scratch holds nothing at a label *)
                   if scratch >= 0 andalso Array.sub (!c, scratch) <> cUnset then setCell (scratch, cUnset) else ();
                   if loop orelse handler >= 0 then widen (mine ()) else ();
                   if loop then (Array.update (heads, l, SOME (!c, !depth)); shared := true) else ();
                   if handler >= 0 then begins := handler else ())
                else ()
              end

          fun okReg r =
            if r >= 0 andalso r < nl then true
            else (breach ("register " ^ i2s r ^ " is not of the frame of " ^ i2s nl); false)
          fun readCell r =
            if not (okReg r) then cell (ANY, 0)
            else
              let val x = Array.sub (!c, r)
              in if cRep x = UNSET then (breach ("reads register " ^ i2s r ^ ", which is not set on every way here"); cell (decl r, 0)) else x end
          fun read r = cRep (readCell r)
          (* what register r holds, unset or not (a read has said so) *)
          fun cellOf r =
            if r < 0 orelse r >= nl1 then cell (ANY, 0)
            else let val x = Array.sub (!c, r) in if cRep x = UNSET then cell (decl r, 0) else x end
          fun down opc = Array.update (downcasts, opc, Array.sub (downcasts, opc) + 1)
          (* which operand a read is, for a message: k < 100 the operand at
             k, 100 + j the j-th of the list *)
          fun operandName (opc, k) =
            if k < 100 then opName opc
            else
              let val j = k - 100
              in
                case #listHolds (Vector.sub (infos, opc)) of
                  SOME (R.ParamsOf _) => opName opc ^ " argument " ^ i2s j
                | SOME (R.CapturesOf _) => "slot " ^ i2s j ^ " of a closure"
                | SOME (R.ArgsOf p) => "argument " ^ i2s j ^ " of " ^ primName (nth (!curOps, p))
                | _ => opName opc ^ " register " ^ i2s j
              end
          (* a read of register r, which must hold q *)
          fun need (opc, r, q, k) =
            if q = ANY then ignore (readCell r)
            else
              let val x = read r
              in
                if x = q orelse le (x, q) then ()
                else if le (q, x) then down opc
                else breach (operandName (opc, k) ^ ": register " ^ i2s r ^ " holds " ^ repName x ^ " where " ^ repName q ^ " is wanted")
              end
          (* register d := the value of cell x *)
          fun write (opc, d, x) =
            if not (okReg d) then ()
            else
              let val q = decl d val m = cRep x
              in
                if m = q orelse q = ANY orelse le (m, q) then setCell (d, x)
                else if le (q, m) then (down opc; setCell (d, cell (q, cFact x)))
                else (breach (opName opc ^ " writes " ^ repName m ^ " into register " ^ i2s d ^ ", which holds " ^ repName q);
                      setCell (d, cell (q, cFact x)))
              end
          fun factOf r = if r < 0 orelse r >= nl1 then 0 else cFact (Array.sub (!c, r))
          fun tagOf r = let val f = factOf r in if f >= 1 andalso f < notBase then f - 1 else ~1 end
          fun closOf r = let val f = factOf r in if f >= closBase then f - closBase else ~1 end
          fun setFact (r, fact) = if r < 0 orelse r >= nl1 then () else setCell (r, cell (cRep (Array.sub (!c, r)), fact))
          fun stop () = reach := false
          fun leaving opc = if !depth = 0 then () else breach (opName opc ^ " with " ^ i2s (!depth) ^ " handlers pushed")

          (* the function an operand names: its index, or ~1 for an import
             (a unit's), after a breach where it is none *)
          fun callee (opc, fid) =
            case idx fid of
              ~1 => (if unitMode then unchecked := !unchecked + 1 else breach (opName opc ^ " of no function f" ^ i2s fid); ~1)
            | i => i

          (* a value, of the instruction with these operands: the
             representation a register must hold *)
          fun want (ops, v) : int =
            case v of
              R.Is r => r
            | R.GlobalOf k =>
                let val g = nth (ops, k)
                in if g < 0 orelse g >= nglobals then (breach ("no global " ^ i2s g); ANY) else globalRep g end
            | R.SlotOf (k, e) =>
                (case closOf (nth (ops, k)) of
                   ~1 => (unchecked := !unchecked + 1; ANY)
                 | i =>
                     let val capt = Vector.sub (captV, i) val e = nth (ops, e)
                     in
                       if e < 0 orelse e >= Vector.length capt
                       then (breach ("a slot " ^ i2s e ^ " of a closure that captures " ^ i2s (Vector.length capt)); ANY)
                       else Vector.sub (capt, e)
                     end)
            | R.Returned => declaredResult
            | R.ResultOf k => let val pn = nth (ops, k) in if pn >= 0 andalso pn < nprims then Vector.sub (primRes, pn) else ANY end
            | R.ReturnOf k => (case idx (nth (ops, k)) of ~1 => ANY | i => resultOf i)
            | _ => ANY
          (* ... and the cell a register is written: a representation and a
             fact *)
          fun made (opc, ops, v) : int =
            case v of
              R.Is r => cell (r, 0)
            | R.Like k => cellOf (nth (ops, k))
            | R.ConstOf k =>
                let val n = nth (ops, k)
                in if n < 0 orelse n >= nconsts then (breach ("no constant " ^ i2s n); cell (ANY, 0)) else cell (constRep n, 0) end
            | R.EnvOf k =>
                let val e = nth (ops, k)
                in
                  if e < 0 orelse e >= Vector.length capt
                  then (breach (opName opc ^ " " ^ i2s e ^ " of a function whose closures capture " ^ i2s (Vector.length capt)); cell (ANY, 0))
                  else cell (Vector.sub (capt, e), 0)
                end
            | R.Left => cell (!dueRep, 0)
            | R.UnitOr (k, r) => cell (if nth (ops, k) = 0 then RUNIT else r, 0)
            | v => cell (want (ops, v), 0)

          (* the reads of the operands before the list *)
          fun reads (opc, ops, rd) =
            case rd of
              [] => ()
            | (k, v) :: rd => (need (opc, nth (ops, k), want (ops, v), k); reads (opc, ops, rd))
          (* the writes, with a fact of a constructor made or a closure *)
          fun writes (opc, ops, info : opinfo, wr) =
            case wr of
              [] => ()
            | (k, v) :: wr =>
                let
                  val y = made (opc, ops, v)
                  val y = if #tag info >= 0 then cell (cRep y, 1 + nth (ops, #tag info))
                          else if #closes info >= 0 then (case idx (nth (ops, #closes info)) of ~1 => y | i => cell (cRep y, closBase + i))
                          else y
                in write (opc, nth (ops, k), y); writes (opc, ops, info, wr) end
          (* the reads of the list, each holding the same, or what the
             callee's parameter of its place does *)
          fun readsSame (opc, q, rs, j) =
            case rs of [] => () | r :: rs => (need (opc, r, q, 100 + j); readsSame (opc, q, rs, j + 1))
          fun readsEach (opc, qs : int vector, rs, j) =
            case rs of
              [] => ()
            | r :: rs => (need (opc, r, if j < Vector.length qs then Vector.sub (qs, j) else ANY, 100 + j); readsEach (opc, qs, rs, j + 1))
          fun readsSlots (opc, qs : int vector, rs, j) =
            case rs of
              [] => ()
            | r :: rs =>
                ((* a slot set after (SETENV): the scratch holds unit for it *)
                 if r = scratch andalso okReg r andalso cRep (Array.sub (!c, r)) = RUNIT then ()
                 else need (opc, r, if j < Vector.length qs then Vector.sub (qs, j) else ANY, 100 + j);
                 readsSlots (opc, qs, rs, j + 1))
          fun readsAny rs = List.app (fn r => ignore (readCell r)) rs
          (* a constructor taken apart: of the tag a fact says (by hand) *)
          fun untag (opc, ops) =
            let val t = tagOf (nth (ops, 1))
            in if t < 0 orelse t = nth (ops, 2) then () else breach (opName opc ^ " of tag " ^ i2s (nth (ops, 2)) ^ " where a test says " ^ i2s t) end

          (* ---- one instruction, by RegCodes' tables ---- *)
          fun instr (opc, ops) =
            let val info : opinfo = Vector.sub (infos, opc)
            in
              if !dueOp = opc andalso opc = R.RESULT andalso !begins < 0 then
                (ninstr := !ninstr + 1; dueOp := ~1;
                 case ops of [d] => write (opc, d, cell (!dueRep, 0)) | _ => breach ("the operands of " ^ opName opc))
              else if !dueOp >= 0 orelse !begins >= 0 then instr' (opc, ops)
              else if #simple info then
                (ninstr := !ninstr + 1;
                 if List.length ops = #nfixed info then () else breach ("the operands of " ^ opName opc);
                 reads (opc, ops, #rd info);
                 if #readsClosure info andalso not (isSome (Array.sub (readsClosure, fi)))
                 then Array.update (readsClosure, fi, SOME (opName opc)) else ();
                 writes (opc, ops, info, #wr info);
                 if opc = R.DECON orelse opc = R.FIELD then untag (opc, ops) else ())
              (* the commonest of the others, by hand, as their tables say *)
              else if opc = R.JUMP then
                (case ops of [l] => (ninstr := !ninstr + 1; arrive (l, 1, ~1, 0); stop ()) | _ => instr' (opc, ops))
              else if opc = R.RET then
                (case ops of [s] => (ninstr := !ninstr + 1; need (opc, s, declaredResult, 0); leaving opc; stop ())
                           | _ => instr' (opc, ops))
              else if opc = R.JUMPIF orelse opc = R.JUMPIFNOT then
                (case ops of [s, l] => (ninstr := !ninstr + 1; need (opc, s, RCON0, 0); arrive (l, 0, ~1, 0))
                           | _ => instr' (opc, ops))
              else if opc = R.PRIM then
                (case ops of
                   pn :: d :: rs =>
                     if pn < 0 orelse pn >= nprims orelse Vector.sub (primArities, pn) <> List.length rs
                        orelse Vector.sub (primImage, pn) then instr' (opc, ops)
                     else (ninstr := !ninstr + 1;
                           readsEach (opc, Vector.sub (primArgs, pn), rs, 0);
                           write (opc, d, cell (Vector.sub (primRes, pn), 0)))
                 | _ => instr' (opc, ops))
              else instr' (opc, ops)
            end
          and instr' (opc, ops) =
            let
              val () = ninstr := !ninstr + 1
              val info : opinfo = Vector.sub (infos, opc)
              val list = case drop (ops, #nfixed info) of SOME l => l | NONE => (breach ("the operands of " ^ opName opc); [])
              (* the list as long as it says *)
              val () =
                if #listAt info < 0 then (if List.null list then () else breach ("the operands of " ^ opName opc))
                else
                  let
                    val v = nth (ops, #listAt info)
                    val n = if #listPrim info then (if v >= 0 andalso v < nprims then Vector.sub (primArities, v) else ~1) else v
                  in
                    if n = List.length list then ()
                    else breach ("a list of " ^ i2s (List.length list) ^ " registers where " ^ opName opc ^ " says " ^ i2s n)
                  end
              (* what is due: the instruction the one before wants, or a
                 handler's first *)
              val left =
                if !dueOp < 0 then false
                else if !dueOp = opc then (dueOp := ~1; true)
                else (breach (opName (!dueOp) ^ " is due after " ^ opName (!dueFrom) ^ ", not " ^ opName opc); dueOp := ~1; false)
              val atHandler = !begins
              val () = begins := ~1
              val () = if atHandler >= 0 andalso atHandler <> opc
                       then breach ("a handler's block that does not begin with " ^ opName atHandler) else ()
              val () = if #takes info andalso not left andalso atHandler <> opc
                       then breach (opName opc ^ " where nothing left a value for it") else ()
              (* the reads *)
              val () = reads (opc, ops, #rd info)
              val () =
                case #listHolds info of
                  NONE => ()
                | SOME (R.Is q) => readsSame (opc, q, list, 0)
                | SOME (R.ParamsOf k) =>
                    (case callee (opc, nth (ops, k)) of
                       ~1 => readsAny list
                     | i =>
                         (if List.length list <> arityOf i
                          then breach (opName opc ^ " of f" ^ i2s (nth (ops, k)) ^ " with " ^ i2s (List.length list) ^ " arguments, whose arity is "
                                       ^ i2s (arityOf i))
                          else ();
                          readsEach (opc, Vector.sub (repsV, i), list, 0)))
                | SOME (R.CapturesOf k) =>
                    (case callee (opc, nth (ops, k)) of
                       ~1 => readsAny list
                     | i =>
                         let val capt = Vector.sub (captV, i)
                         in
                           if List.length list <> Vector.length capt
                           then breach ("a closure of f" ^ i2s (nth (ops, k)) ^ " capturing " ^ i2s (List.length list)
                                        ^ " where its closures capture " ^ i2s (Vector.length capt))
                           else ();
                           readsSlots (opc, capt, list, 0)
                         end)
                | SOME (R.ArgsOf k) =>
                    let val pn = nth (ops, k)
                    in readsEach (opc, if pn >= 0 andalso pn < nprims then Vector.sub (primArgs, pn) else Vector.fromList [], list, 0) end
                | SOME _ => readsAny list
              (* which primitives it names *)
              val () =
                if #image info < 0 orelse #prim info < 0 then ()
                else
                  let val pn = nth (ops, #prim info)
                  in
                    if pn < 0 orelse pn >= nprims then breach ("no primitive " ^ i2s pn)
                    else if Vector.sub (primImage, pn) = (#image info = 1) then ()
                    else if #image info = 1 then breach (opName opc ^ " of " ^ primName pn ^ ", which is no image primitive")
                    else breach ("the image primitive " ^ primName pn ^ " in " ^ opName opc)
                  end
              (* what it does beside its operands *)
              val () =
                if #readsClosure info andalso not (isSome (Array.sub (readsClosure, fi)))
                then Array.update (readsClosure, fi, SOME (opName opc)) else ()
              val () =
                if #closes info < 0 then ()
                else case idx (nth (ops, #closes info)) of
                       ~1 => ()
                     | i => (Array.update (closed, i, true);
                             if arityOf i <> 1 then breach ("a closure of f" ^ i2s (nth (ops, #closes info)) ^ ", of arity " ^ i2s (arityOf i)) else ())
              val () = if #known info < 0 then () else case idx (nth (ops, #known info)) of ~1 => () | i => Array.update (calledKnown, i, true)
              (* the writes *)
              val () = writes (opc, ops, info, #wr info)
              val () = if #leavesFor info >= 0 then (dueOp := #leavesFor info; dueRep := want (ops, #leaves info); dueFrom := opc) else ()
              val () = if opc = R.DECON orelse opc = R.FIELD then untag (opc, ops) else ()
              val l = if #label info < 0 then ~1 else nth (ops, #label info)
            in
              (* the handlers, then where control goes *)
              (case #handlers info of
                 R.Installs =>
                   (if okLabel l then
                      (if Array.sub (labelFn, l) >= 0 then breach ("a handler at L" ^ i2s l ^ ", before its PUSHHANDLER") else ();
                       Array.update (handlerOf, l, #begins info))
                    else ();
                    arrive (l, 2, ~1, 0);
                    depth := !depth + 1)
               | R.Removes => if !depth = 0 then breach (opName opc ^ " with no handler") else depth := !depth - 1
               | R.Keeps => ());
              case #flow info of
                R.Next => ()
              | R.Call => ()
              | R.Branch =>
                  if opc = R.JUMPIFNOTTAG then
                    (* a test a fact answers: one way untaken (by hand) *)
                    let val s = nth (ops, 0) val t = nth (ops, 2) val t' = tagOf s
                    in
                      if t' >= 0 then (if t' = t then () else (arrive (l, 0, ~1, 0); stop ()))
                      else (arrive (l, 0, s, notBase + t); setFact (s, 1 + t))
                    end
                  else arrive (l, 0, ~1, 0)
              | R.Jump => (arrive (l, 1, ~1, 0); stop ())
              | R.Return => (leaving opc; stop ())
              | R.TailCall =>
                  (leaving opc;
                   (* a known one returns what this one does *)
                   if #known info < 0 then ()
                   else
                     (case idx (nth (ops, #known info)) of
                        ~1 => ()
                      | i => let val m = resultOf i
                             in
                               if le (m, declaredResult) then ()
                               else if le (declaredResult, m) then down opc
                               else breach (opName opc ^ " of f" ^ i2s (nth (ops, #known info)) ^ ", which returns " ^ repName m
                                            ^ " where this one returns " ^ repName declaredResult)
                             end);
                   stop ())
              | R.Raise => stop ()
              | R.Halt => stop ()
              | R.Switch =>
                  if #table info < 0 then ()
                  else (table := nth (ops, #table info); tableSubject := nth (ops, 0); tableTag := 0;
                        tableKnown := tagOf (nth (ops, 0)))
            end

          (* code no way reaches still says which closures and known calls
             the program has: what they are of may be entered by another
             way *)
          fun unreached (opc, ops) =
            if opc < 0 orelse opc >= R.count then ()
            else
              let val info : opinfo = Vector.sub (infos, opc)
              in
                if #closes info < 0 then () else (case idx (nth (ops, #closes info)) of ~1 => () | i => Array.update (closed, i, true));
                if #known info < 0 then () else (case idx (nth (ops, #known info)) of ~1 => () | i => Array.update (calledKnown, i, true))
              end
          fun ins (opc, ops) =
            if not (!reach) then unreached (opc, ops)
            else
              (curOpc := opc; curOps := ops;
               if opc < 0 orelse opc >= R.count then breach ("no opcode " ^ i2s opc)
               else if !table > 0 then
                 (* an entry of a SWITCH's table: a JUMP of the tag it is *)
                 (ninstr := !ninstr + 1;
                  if opc = R.JUMP then
                    (case ops of
                       [l] => if !tableKnown < 0 orelse !tableKnown = !tableTag
                              then arrive (l, 3, !tableSubject, 1 + !tableTag) else ()
                     | _ => breach "the operands of a SWITCH's JUMP")
                  else breach ("a SWITCH's table that has " ^ opName opc);
                  table := !table - 1;
                  tableTag := !tableTag + 1;
                  (* a known tag within the table: past it is untaken *)
                  if !table = 0 andalso !tableKnown >= 0 andalso !tableKnown < !tableTag then stop () else ())
               else instr (opc, ops))

          fun items ([], _) = ()
            | items (it :: rest, k) =
                (pos := k;
                 (case it of
                    C.Lab l => (curOpc := ~1; label l)
                  | C.Pos _ => ()
                  | C.Op (opc, args) => ins (opc, args)
                  | C.Ops (opc, args) => ins (opc, List.map (fn C.I v => v | C.L l => l) args)
                  | C.OpLab (opc, l) => ins (opc, [l])
                  | C.OpLabImm (opc, l, x) => ins (opc, [l, x]));
                 items (rest, k + 1))
          val () = items (#code f, 0)
        in
          curOpc := ~1;
          if !reach then breach "the code falls off its end" else ();
          if !dueOp >= 0 then breach (opName (!dueOp) ^ " is due after " ^ opName (!dueFrom) ^ " at the end") else ();
          if !table > 0 then breach "a SWITCH's table cut short" else ();
          List.app (fn l => if Array.sub (labelFn, l) = fi then () else breach ("a jump to L" ^ i2s l ^ ", which is no label of the function"))
                   (!forwards)
        end

      val () = Vector.appi (fn (i, _) => func i) funcs
      (* what one function's code says of another's *)
      val () =
        Vector.appi (fn (i, f : C.func) =>
                       case Array.sub (readsClosure, i) of
                         NONE => ()
                       | SOME what =>
                           (if Array.sub (closed, i) then ()
                            else (nbreach := !nbreach + 1;
                                  msgs := ("function " ^ #name f ^ " (f" ^ i2s (#id f) ^ "): " ^ what ^ " in a function no closure is made of") :: !msgs);
                            if Array.sub (calledKnown, i)
                            then (nbreach := !nbreach + 1;
                                  msgs := ("function " ^ #name f ^ " (f" ^ i2s (#id f) ^ "): " ^ what ^ " in a function CALLK calls, with no closure") :: !msgs)
                            else ()))
                    funcs
      val ndown = Array.foldl (op +) 0 downcasts
    in
      {breaches = !nbreach, messages = List.rev (!msgs),
       counts = [("functions", nf), ("instructions", !ninstr), ("downcasts", ndown), ("unchecked", !unchecked)]
                @ List.mapPartial (fn (opc, n) => if n = 0 then NONE else SOME ("downcasts " ^ opName opc, n))
                                  (List.tabulate (R.count, fn opc => (opc, Array.sub (downcasts, opc))))}
    end

  (* site: where it runs ("registers", "link"); mode as verify's *)
  fun run (site : string, mode : string, p : C.program) : unit =
    if List.all (fn (f : C.func) => not (isSome (#meta f))) (#funcs p) then ()
    else
      let
        val {breaches, messages, counts} = verify (mode, p)
      in
        if setting () = "census" then
          List.app (fn (k, n) => TextIO.output (TextIO.stdErr, "regverify\t" ^ site ^ "\t" ^ mode ^ "\t" ^ k ^ "\t" ^ i2s n ^ "\n")) counts
        else ();
        if breaches = 0 then ()
        else
          Error.bug ("regverify" ^ (if site = "link" then " at the link" else "") ^ ": " ^ i2s breaches
                     ^ (if breaches = 1 then " breach; " else " breaches; ")
                     ^ String.concatWith "; " (List.take (messages, Int.min (5, List.length messages))))
      end

  (* the stage's check, and the link's, each by its key and level *)
  fun checked (key : string, site : string, mode : unit -> string) (p : C.program) : unit =
    case level () of
      SOME l => Pass.checkAt (key, l) (fn p => run (site, mode (), p)) p
    | NONE => ()
  fun stage (p : C.program) = checked ("regverify", "registers", fn () => if !Pass.whole then "whole" else "unit") p
  fun linked (p : C.program) = checked ("regverify-link", "link", fn () => "linked") p

  (* ---- faults, for the negative tests of the check ----
     RUNE_REGVERIFY_INJECT=KIND or KIND@N corrupts the N-th place (from 0)
     of that kind in the code Regs made, before it is checked and written,
     so that the check, the loader and the JIT can each be asked what they
     make of it (tests/runner/regverify.sml; docs/plans/correctness/vm-verifier.md).
     It says on stderr what it did, or that it found no place. The kinds:
       rep-write  an INT into an int register made CON0
       rep-read   int_add's first argument made a ptr register of the frame
       unset      the first INT dropped, whose register is read later
       noresult   the RESULT after a CALLK dropped
       arity      a CALLK given one argument more
       catch      a handler's CATCH dropped
       switch     the first JUMP of a SWITCH's table dropped
       env        ENV d e made ENV d (e + 7)
       pop        a POPHANDLER dropped
       image      a PRIMPUSH made a PRIM
       closure    a CLOSURE made of a function of arity 2 *)
  fun inject (p : C.program) : C.program =
    case OS.Process.getEnv "RUNE_REGVERIFY_INJECT" of
      NONE => p
    | SOME "" => p
    | SOME spec =>
        let
          val (kind, nth) =
            case String.tokens (fn ch => ch = #"@") spec of
              [k, n] => (k, case Int.fromString n of SOME n => n | NONE => 0)
            | _ => (spec, 0)
          val seen = ref 0
          val did = ref ""
          fun hit () = (seen := !seen + 1; !seen - 1 = nth)
          val intAdd = case Prims.find "int_add" of SOME (i, _) => i | NONE => ~1
          val arity2 = List.find (fn (f : C.func) => case #meta f of SOME {arity, ...} => arity = 2 | NONE => false) (#funcs p)
          fun func (f : C.func) : C.func =
            case #meta f of
              NONE => f
            | SOME (meta as {reps, ...}) =>
                let
                  val rv = Vector.fromList reps
                  fun decl r = if r >= 0 andalso r < Vector.length rv then Vector.sub (rv, r) else ANY
                  val ptrReg =
                    let fun go i = if i >= Vector.length rv - 1 then NONE else if Vector.sub (rv, i) = RPTR then SOME i else go (i + 1)
                    in go 0 end
                  val scratch = #nlocals f - 1
                  fun note what = did := what ^ " in " ^ #name f ^ " (f" ^ i2s (#id f) ^ ")"
                  fun go (prev, items) =
                    case items of
                      [] => []
                    | it :: rest =>
                        let
                          val ops = case it of
                                      C.Op (opc, a) => SOME (opc, a)
                                    | C.Ops (opc, a) => SOME (opc, List.map (fn C.I v => v | C.L l => l) a)
                                    | _ => NONE
                          fun keep () = it :: go (SOME it, rest)
                          val free = !did = ""
                        in
                          case (kind, ops) of
                            ("rep-write", SOME (opc, [d, _])) =>
                              if opc = R.INT andalso decl d = RINT andalso free andalso hit ()
                              then (note "CON0 into an int register"; C.Op (R.CON0, [d, 0]) :: go (SOME it, rest)) else keep ()
                          | ("rep-read", SOME (opc, pn :: d :: _ :: b)) =>
                              if opc = R.PRIM andalso pn = intAdd andalso isSome ptrReg andalso free andalso hit ()
                              then (note ("int_add of the ptr register " ^ i2s (valOf ptrReg));
                                    C.Op (R.PRIM, pn :: d :: valOf ptrReg :: b) :: go (SOME it, rest))
                              else keep ()
                          | ("unset", SOME (opc, [d, _])) =>
                              if opc = R.INT andalso d <> scratch andalso free andalso hit ()
                              then (note ("INT " ^ i2s d ^ " dropped"); go (prev, rest)) else keep ()
                          | ("noresult", SOME (opc, _)) =>
                              if opc = R.RESULT andalso (case prev of SOME (C.Op (p', _)) => p' = R.CALLK | _ => false)
                                 andalso free andalso hit ()
                              then (note "RESULT dropped"; go (prev, rest)) else keep ()
                          | ("arity", SOME (opc, fid :: n :: a)) =>
                              if opc = R.CALLK andalso not (null a) andalso free andalso hit ()
                              then (note "CALLK given one argument more"; C.Op (R.CALLK, fid :: (n + 1) :: a @ [hd a]) :: go (SOME it, rest))
                              else keep ()
                          | ("catch", SOME (opc, _)) =>
                              if opc = R.CATCH andalso free andalso hit () then (note "CATCH dropped"; go (prev, rest)) else keep ()
                          | ("switch", SOME (opc, _)) =>
                              if opc = R.SWITCH andalso free andalso hit ()
                              then (note "a SWITCH's first JUMP dropped";
                                    it :: (case rest of
                                             C.Ops (j, _) :: rest' => if j = R.JUMP then go (SOME it, rest') else go (SOME it, rest)
                                           | _ => go (SOME it, rest)))
                              else keep ()
                          | ("env", SOME (opc, [d, e])) =>
                              if opc = R.ENV andalso free andalso hit ()
                              then (note "ENV out of range"; C.Op (R.ENV, [d, e + 7]) :: go (SOME it, rest)) else keep ()
                          | ("pop", SOME (opc, _)) =>
                              if opc = R.POPHANDLER andalso free andalso hit () then (note "POPHANDLER dropped"; go (prev, rest)) else keep ()
                          | ("image", SOME (opc, pn :: a)) =>
                              if opc = R.PRIMPUSH andalso free andalso hit ()
                              then (note "PRIMPUSH made PRIM";
                                    C.Op (R.PRIM, pn :: scratch :: a)
                                    :: (case rest of
                                          C.Op (r, [_]) :: rest' => if r = R.RESULT then go (SOME it, rest') else go (SOME it, rest)
                                        | _ => go (SOME it, rest)))
                              else keep ()
                          | ("closure", SOME (opc, d :: _ :: n :: a)) =>
                              if opc = R.CLOSURE andalso isSome arity2 andalso free andalso hit ()
                              then (note ("CLOSURE of f" ^ i2s (#id (valOf arity2)) ^ ", of arity 2");
                                    C.Op (R.CLOSURE, d :: #id (valOf arity2) :: n :: a) :: go (SOME it, rest))
                              else keep ()
                          | _ => keep ()
                        end
                in
                  {id = #id f, nlocals = #nlocals f, code = go (NONE, #code f), name = #name f, meta = SOME meta}
                end
          val p' = {consts = #consts p, nglobals = #nglobals p, funcs = List.map func (#funcs p), files = #files p,
                    inlines = #inlines p, nlabels = #nlabels p, globalReps = #globalReps p}
        in
          TextIO.output (TextIO.stdErr, "regverify inject " ^ spec ^ ": " ^ (if !did = "" then "no place found" else !did) ^ "\n");
          p'
        end
end
