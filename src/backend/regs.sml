(* The register target (docs/ir.md; docs/plans/middle-end.md, M5): the
   register bytecode of vm/new (src/isa/regs.sml) from Low.

   * Every variable has a register, shared by linear scan as the stack
     target shares locals: every edge of Low goes forward, but the jump back
     to the head of a loop, across which only the head's parameters live, so
     a variable lives from where it is made to its last use in the order of
     the blocks. The parameters are registers 0 to n-1. One more register,
     the scratch, takes what nothing reads (a call's result, a primitive's)
     and breaks a cycle of moves.
   * A call is CALL, or CALLK of a known function, and then RESULT, which
     takes what it returns; a primitive that saves or restores an image is
     PRIMPUSH and RESULT, so that an image resumes at RESULT; a handler's
     block begins with CATCH.
   * The arguments of a jump move into the block's parameters in parallel;
     a jump to the next block falls through, and one to a block that only
     returns its parameter returns. *)
structure Regs : TARGET where type code = Codegen.program =
struct
  structure L = Low
  structure C = Codegen
  structure R = RegCodes

  type code = Codegen.program
  val info : Target.t = {name = "registers", machine = Target.Registers, intBits = 64, maxArgs = 64, switch = false,
                         barriers = false, safepoints = false}

  fun bug msg = Error.bug ("Regs: " ^ msg)

  val int32Max : IntInf.int = IntInf.fromInt 1073741823
  val int32Min : IntInf.int = IntInf.fromInt ~1073741824

  (* the primitives that save or restore an image (Isa.effect) *)
  val imagePrims = ["posix_fork", "rt_save", "rt_restore"]

  fun func (f : L.func) : C.func =
    let
      val blocks = Vector.fromList (#blocks f)
      val nblocks = Vector.length blocks
      val nv = Int.max (#nvars f, 1)
      (* what is known of each variable and label, in arrays: they are
         numbered from 0 in a function (Low.func) *)
      val index =
        let
          val top = Vector.foldl (fn ({label, ...} : L.block, m) => Int.max (label, m)) 0 blocks
          val a = Array.array (top + 1, ~1)
        in Vector.appi (fn (i, {label, ...} : L.block) => Array.update (a, label, i)) blocks; a end
      fun blockIndex l =
        if l >= 0 andalso l < Array.length index andalso Array.sub (index, l) >= 0 then Array.sub (index, l)
        else bug "a jump to no block"

      val uses : int array = Array.array (nv, 0)
      fun use x = Array.update (uses, x, Array.sub (uses, x) + 1)
      fun usesOf x = Array.sub (uses, x)
      val () =
        Vector.app (fn ({instrs, transfer, ...} : L.block) =>
                      (List.app (fn L.Def (_, oper) => List.app use (L.uses oper) | _ => ()) instrs;
                       List.app use (L.transferUses transfer)))
                   blocks

      fun returnsParam i =
        case Vector.sub (blocks, i) of
          {params = [p], instrs, transfer = L.Return r, ...} =>
            r = p andalso List.all (fn L.At _ => true | _ => false) instrs
        | _ => false
      fun forward i =
        case Vector.sub (blocks, i) of
          {params = [], instrs, transfer = L.Goto (l, []), ...} =>
            if List.all (fn L.At _ => true | _ => false) instrs then SOME (blockIndex l) else NONE
        | _ => NONE
      fun target i = case forward i of SOME j => if j > i then target j else i | NONE => i

      (* ---- the registers ---- *)
      val first : int array = Array.array (nv, ~1)
      val last : int array = Array.array (nv, ~1)
      val pos = ref 0
      fun born x = if Array.sub (first, x) >= 0 then () else Array.update (first, x, !pos)
      fun seen x = Array.update (last, x, !pos)
      val () = List.app (fn x => (born x; seen x)) (#params f)
      fun isParam x = List.exists (fn p => p = x) (#params f)
      val () =
        Vector.app (fn ({params, instrs, transfer, ...} : L.block) =>
                      (pos := !pos + 1;
                       List.app born params;
                       List.app (fn L.Def (x, oper) => (pos := !pos + 1; List.app seen (L.uses oper); born x)
                                  | _ => ()) instrs;
                       pos := !pos + 1;
                       List.app seen (L.transferUses transfer)))
                   blocks
      val regs : int array = Array.array (nv, ~1)
      val _ = List.foldl (fn (x, k) => (Array.update (regs, x, k); k + 1)) 0 (#params f)
      val nregs = ref (Int.max (List.length (#params f), 1))
      val () =
        let
          val buckets : int list array = Array.array (!pos + 1, [])
          val () =
            Array.appi (fn (x, s) =>
                          if s < 0 orelse isParam x orelse usesOf x = 0 then ()
                          else Array.update (buckets, s, x :: Array.sub (buckets, s)))
                       first
          val byStart = Array.foldr (fn (xs, acc) => List.revAppend (xs, acc)) [] buckets
          fun insert (k, []) = [k]
            | insert (k, k' :: rest) = if k < k' then k :: k' :: rest else k' :: insert (k, rest)
          val params = #1 (List.foldl (fn (x, (ps, k)) => ((Int.max (Array.sub (last, x), 0), k) :: ps, k + 1))
                                      ([], 0) (#params f))
          (* a register is given again only after the instruction that last
             reads it: a register instruction may write its destination
             before it has read every operand (PRIM, TUPLE read theirs first,
             but a list and a result must not share) *)
          fun alloc ([], _, _) = ()
            | alloc (x :: rest, free, active) =
                let
                  val s = Array.sub (first, x)
                  val (expired, still) = List.partition (fn (e, _) => e < s) active
                  val free = List.foldl (fn ((_, k), fr) => insert (k, fr)) free expired
                  val (r, free) =
                    case free of
                      k :: more => (k, more)
                    | [] => let val k = !nregs in nregs := k + 1; (k, []) end
                  val e = let val e = Array.sub (last, x) in if e < 0 then s else e end
                in
                  Array.update (regs, x, r);
                  alloc (rest, free, (e, r) :: still)
                end
        in alloc (byStart, [], params) end
      val scratch = !nregs
      val nlocals = scratch + 1
      fun reg x = let val r = Array.sub (regs, x) in if r < 0 then scratch else r end

      (* ---- the code ---- *)
      val code : C.item list ref = ref []
      fun emit it =
        case (it, !code) of
          (C.Pos _, C.Pos _ :: rest) => code := it :: rest
        | _ => code := it :: !code
      val here : (int * int * int) ref = ref (~1, ~1, ~1)
      fun at (sp : Source.span) =
        case Source.lineColOf sp of
          NONE => ()
        | SOME (file, line, col) =>
            let val p = (C.fileIdx file, line, col)
            in if p = !here then () else (here := p; emit (C.Pos p)) end
      val () = case #pos f of SOME sp => at sp | NONE => ()
      val labels = Vector.tabulate (nblocks, fn _ => C.newLabel ())
      fun labelOf i = Vector.sub (labels, i)
      fun op' (opc, args) = emit (C.Op (opc, args))

      fun operation (x, oper) =
        let val d = reg x
        in
          case oper of
            L.Const (Lambda.CInt i) =>
              if IntInf.>= (i, int32Min) andalso IntInf.<= (i, int32Max) then op' (R.INT, [d, IntInf.toInt i])
              else op' (R.CONST, [d, C.constIdx (Lambda.CInt i)])
          | L.Const c => op' (R.CONST, [d, C.constIdx c])
          | L.Unit => op' (R.UNIT, [d])
          | L.Con0 t => op' (R.CON0, [d, t])
          | L.Global g => op' (R.GLOBAL, [d, C.globalIdx g])
          | L.SetGlobal (g, v) => (op' (R.SETGLOBAL, [C.globalIdx g, reg v]); if usesOf x > 0 then op' (R.UNIT, [d]) else ())
          | L.Env i => op' (R.ENV, [d, i])
          | L.Self => op' (R.SELF, [d])
          | L.Call (fv, a) => (op' (R.CALL, [reg fv, reg a]); op' (R.RESULT, [d]))
          | L.CallK (fid, vs) => (op' (R.CALLK, fid :: List.length vs :: List.map reg vs); op' (R.RESULT, [d]))
          | L.Prim (p, vs) =>
              if List.exists (fn q => q = p) imagePrims then
                (op' (R.PRIMPUSH, C.primIdx p :: List.map reg vs); op' (R.RESULT, [d]))
              else op' (R.PRIM, C.primIdx p :: d :: List.map reg vs)
          | L.Tuple vs => op' (R.TUPLE, d :: List.length vs :: List.map reg vs)
          | L.Select (i, v) => op' (R.SELECT, [d, i, reg v])
          | L.Con (t, v) => op' (R.CON, [d, t, reg v])
          | L.Decon v => op' (R.DECON, [d, reg v])
          | L.ConTag v => op' (R.CONTAG, [d, reg v])
          | L.NewExn n => op' (R.NEWEXN, [d, C.constIdx (Lambda.CString n)])
          | L.BuiltinExn k => op' (R.BUILTINEXN, [d, k])
          | L.MkExn (c, p) => op' (R.MKEXN, [d, reg c, reg p])
          | L.ExnCon v => op' (R.EXNCON, [d, reg v])
          | L.ExnArg v => op' (R.EXNARG, [d, reg v])
          | L.Closure (fid, vs) =>
              (* a closure of the group not made yet is set after; the
                 scratch holds unit for it *)
              ((if List.exists (fn NONE => true | _ => false) vs then op' (R.UNIT, [scratch]) else ());
               op' (R.CLOSURE, d :: fid :: List.length vs :: List.map (fn SOME v => reg v | NONE => scratch) vs))
          | L.SetEnv (c, i, v) => (op' (R.SETENV, [reg c, i, reg v]); if usesOf x > 0 then op' (R.UNIT, [d]) else ())
        end

      (* Moves in parallel: each destination from its source, none read
         after it is written, a cycle broken through the scratch. *)
      fun moves (pairs : (int * int) list) =
        let
          val pairs = List.filter (fn (d, s) => d <> s) pairs
          fun go [] = ()
            | go ps =
                case List.find (fn (d, _) => not (List.exists (fn (_, s) => s = d) ps)) ps of
                  SOME (d, s) => (op' (R.MOVE, [d, s]); go (List.filter (fn (d', _) => d' <> d) ps))
                | NONE =>
                    (* every destination is still read: a cycle, broken by
                       keeping one destination's value in the scratch *)
                    let val (d, _) = hd ps
                    in
                      op' (R.MOVE, [scratch, d]);
                      go (List.map (fn (d', s') => if s' = d then (d', scratch) else (d', s')) ps)
                    end
        in go pairs end

      fun jump (from, l, vs) =
        let val i = target (blockIndex l)
        in
          if returnsParam i then op' (R.RET, [reg (hd vs)])
          else
            let val {params, ...} = Vector.sub (blocks, i)
            in
              moves (List.filter (fn (d, _) => d <> scratch)
                                 (ListPair.map (fn (p, v) => (if usesOf p = 0 then scratch else reg p, reg v)) (params, vs)));
              if i = from + 1 then () else emit (C.Ops (R.JUMP, [C.L (labelOf i)]))
            end
        end

      val handlers : bool array = Array.array (Int.max (nblocks, 1), false)
      val () =
        Vector.app (fn ({instrs, ...} : L.block) =>
                      List.app (fn L.Push l => Array.update (handlers, blockIndex l, true) | _ => ()) instrs)
                   blocks

      fun block (i, {params, instrs, transfer, ...} : L.block) =
        (emit (C.Lab (labelOf i));
         if Array.sub (handlers, i) then
           (case params of
              [x] => op' (R.CATCH, [reg x])
            | _ => bug "a handler's block of other than one parameter")
         else ();
         List.app (fn L.Def (x, oper) => operation (x, oper)
                    | L.Push l => emit (C.Ops (R.PUSHHANDLER, [C.L (labelOf (blockIndex l))]))
                    | L.Pop => op' (R.POPHANDLER, [])
                    | L.At sp => at sp) instrs;
         case transfer of
           L.Goto (l, vs) => jump (i, l, vs)
         | L.If (v, t, e) =>
             let val ti = target (blockIndex t) val ei = target (blockIndex e)
             in
               if ei = i + 1 then emit (C.Ops (R.JUMPIF, [C.I (reg v), C.L (labelOf ti)]))
               else (emit (C.Ops (R.JUMPIFNOT, [C.I (reg v), C.L (labelOf ei)]));
                     if ti = i + 1 then () else emit (C.Ops (R.JUMP, [C.L (labelOf ti)])))
             end
         | L.IfTag (v, tag, t, e) =>
             let val ti = target (blockIndex t) val ei = target (blockIndex e)
             in
               emit (C.Ops (R.JUMPIFNOTTAG, [C.I (reg v), C.L (labelOf ei), C.I tag]));
               if ti = i + 1 then () else emit (C.Ops (R.JUMP, [C.L (labelOf ti)]))
             end
         | L.Return v => op' (R.RET, [reg v])
         | L.TailCall (fv, a) => op' (R.TAILCALL, [reg fv, reg a])
         | L.TailCallK (fid, vs) => op' (R.TAILCALLK, fid :: List.length vs :: List.map reg vs)
         | L.Raise v => op' (R.RAISE, [reg v]))
      val () = Vector.appi block blocks
    in
      {id = #id f, nlocals = nlocals, code = List.rev (!code), name = #name f}
    end

  fun program (p : L.program) : C.program =
    let
      val () = C.reset ()
      val funcs = List.map func p
      val sorted = IntMap.listItems (List.foldl (fn (f : C.func, m) => IntMap.insert (m, #id f, f)) IntMap.empty funcs)
    in
      {consts = List.rev (!C.consts), nglobals = !C.nglobals, funcs = sorted, files = List.rev (!C.files),
       nlabels = !C.nextLabel}
    end
end
