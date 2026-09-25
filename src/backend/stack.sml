(* The stack target (docs/ir.md; docs/plans/middle-end.md, M4): runevm's
   bytecode from Low, in Codegen's instruction lists, which Emit writes.

   * Constants, globals, captured values and the running closure are pushed
     where they are used, as Codegen pushes them, and never kept in a local.
   * A value used once, by an instruction of its own block that takes it in
     the order the stack gives it, stays on the stack: it is computed where
     that instruction's operands are pushed (a tree), with nothing between
     them that has an effect, so the order of effects is Low's. Every other
     value has a local, stored where it is made and read where it is used.
   * Locals are shared: every edge of Low goes forward in the order of its
     blocks, so a value lives from where it is made to its last use in that
     order, and a local freed there is given again (linear scan). The
     parameter is local 0, as the VM wants.
   * The arguments of a jump are pushed and stored into the block's
     parameters from the last, so they move in parallel; a jump to the next
     block falls through, and one to a block that only returns its
     parameter is a return.
   * A position is noted where it changes, as Codegen does. *)
structure Stack : TARGET where type code = Codegen.program =
struct
  type code = Codegen.program
  val info = Target.stack

  structure L = Low
  structure C = Codegen

  fun bug msg = Error.bug ("Stack: " ^ msg)

  val int32Max : IntInf.int = IntInf.fromInt 1073741823
  val int32Min : IntInf.int = IntInf.fromInt ~1073741824

  fun remat (oper : L.operation) : bool =
    case oper of
      L.Const _ => true | L.Unit => true | L.Con0 _ => true | L.Global _ => true | L.Env _ => true | L.Self => true
    | _ => false

  (* Whether an operation leaves a value on the stack. *)
  fun pushes (oper : L.operation) : bool =
    case oper of
      L.SetGlobal _ => false
    | L.SetEnv _ => false
    | _ => true

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

      (* the definitions, and how often each variable is used *)
      val defs : L.operation option array = Array.array (nv, NONE)
      val uses : int array = Array.array (nv, 0)
      fun use x = Array.update (uses, x, Array.sub (uses, x) + 1)
      fun usesOf x = Array.sub (uses, x)
      val () =
        Vector.app (fn ({instrs, transfer, ...} : L.block) =>
                      (List.app (fn L.Def (x, oper) => (Array.update (defs, x, SOME oper); List.app use (L.uses oper))
                                  | _ => ()) instrs;
                       List.app use (L.transferUses transfer)))
                   blocks
      fun isRemat x = case Array.sub (defs, x) of SOME oper => remat oper | NONE => false

      (* where each block's jump goes when it only returns its parameter *)
      fun returnsParam i =
        case Vector.sub (blocks, i) of
          {params = [p], instrs, transfer = L.Return r, ...} =>
            r = p andalso List.all (fn L.At _ => true | _ => false) instrs
        | _ => false
      (* a block that only jumps on, with nothing to move *)
      fun forward i =
        case Vector.sub (blocks, i) of
          {params = [], instrs, transfer = L.Goto (l, []), ...} =>
            if List.all (fn L.At _ => true | _ => false) instrs then SOME (blockIndex l) else NONE
        | _ => NONE
      fun target i = case forward i of SOME j => if j > i then target j else i | NONE => i

      (* ---- the trees: which values stay on the stack ---- *)

      (* tree x: x is computed where its one use pushes its operands *)
      val tree : bool array = Array.array (nv, false)
      fun isTree x = Array.sub (tree, x)
      val () =
        Vector.app
          (fn ({instrs, transfer, ...} : L.block) =>
             let
               (* pending: the definitions not yet used, which could stay on
                  the stack, latest first *)
               fun operands (vs, pending) =
                 let
                   fun go ([], pending) = pending
                     | go (v :: rest, pending) =
                         if isRemat v orelse not (List.exists (fn p => p = v) pending) then
                           go (rest, pending)       (* pushed where it is used *)
                         else
                           case pending of
                             p :: more => if p = v then (Array.update (tree, v, true); go (rest, more)) else []
                           | [] => []
                 in go (List.rev vs, pending) end
               fun step (i, pending) =
                 case i of
                   L.Def (x, oper) =>
                     if remat oper then pending
                     else
                       let val pending = operands (L.uses oper, pending)
                       in if pushes oper andalso usesOf x = 1 then x :: pending else [] end
                 | L.At _ => pending
                 | _ => []
               val pending = List.foldl step [] instrs
             in
               ignore (operands (L.transferUses transfer, pending))
             end)
          blocks

      (* ---- the locals ---- *)

      (* positions in the order of the blocks: where each variable is made,
         and where it is last used *)
      val first : int array = Array.array (nv, ~1)
      val last : int array = Array.array (nv, ~1)
      val pos = ref 0
      fun born x = if Array.sub (first, x) >= 0 then () else Array.update (first, x, !pos)
      fun seen x = Array.update (last, x, !pos)
      fun needsLocal x = not (isTree x) andalso not (isRemat x)
      val () = (born (#param f); seen (#param f))
      val () =
        Vector.app (fn ({params, instrs, transfer, ...} : L.block) =>
                      (pos := !pos + 1;
                       List.app born params;
                       List.app (fn L.Def (x, oper) => (pos := !pos + 1; List.app seen (L.uses oper); born x)
                                  | _ => ()) instrs;
                       pos := !pos + 1;
                       List.app seen (L.transferUses transfer)))
                   blocks
      val slots : int array = Array.array (nv, ~1)
      val nslots = ref 1
      val () = Array.update (slots, #param f, 0)
      val () =
        let
          (* the variables that want a local, in the order they are made *)
          val buckets : int list array = Array.array (!pos + 1, [])
          val () =
            Array.appi (fn (x, s) =>
                          if s < 0 orelse x = #param f orelse not (needsLocal x) then ()
                          else Array.update (buckets, s, x :: Array.sub (buckets, s)))
                       first
          val byStart = Array.foldr (fn (xs, acc) => List.revAppend (xs, acc)) [] buckets
          fun insert (k, []) = [k]
            | insert (k, k' :: rest) = if k < k' then k :: k' :: rest else k' :: insert (k, rest)
          (* free: the locals no live variable holds, the lowest first;
             active: (last use, local) of the live ones. A local may be given
             to what the instruction that last reads it makes. *)
          val paramEnd = Int.max (Array.sub (last, #param f), 0)
          fun alloc ([], _, _) = ()
            | alloc (x :: rest, free, active) =
                let
                  val s = Array.sub (first, x)
                  val (expired, still) = List.partition (fn (e, _) => e <= s) active
                  val free = List.foldl (fn ((_, k), fr) => insert (k, fr)) free expired
                  val (slot, free) =
                    case free of
                      k :: more => (k, more)
                    | [] => let val k = !nslots in nslots := k + 1; (k, []) end
                  val e = let val e = Array.sub (last, x) in if e < 0 then s else e end
                in
                  Array.update (slots, x, slot);
                  alloc (rest, free, (e, slot) :: still)
                end
        in alloc (byStart, [], [(paramEnd, 0)]) end
      fun slotOf x = let val k = Array.sub (slots, x) in if k < 0 then bug ("no local for v" ^ Int.toString x) else k end

      (* ---- the code ---- *)

      val code : C.item list ref = ref []
      (* a position noted where another was, with nothing between, replaces
         it; a local stored and read at once is TEELOCAL *)
      fun emit it =
        case (it, !code) of
          (C.Pos _, C.Pos _ :: rest) => code := it :: rest
        | (C.Op (opc, [k]), C.Op (opc', [k']) :: rest) =>
            if opc = Opcodes.LOCAL andalso opc' = Opcodes.SETLOCAL andalso k = k' then
              code := C.Op (Opcodes.TEELOCAL, [k]) :: rest
            else code := it :: !code
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

      (* the code of each tree, kept until its use pushes it, with the
         positions in force where it begins and ends *)
      val trees : (C.item list * (int * int * int) * (int * int * int)) option array = Array.array (nv, NONE)
      val pendingTrees = ref 0
      fun restore p = if p = !here orelse p = (~1, ~1, ~1) then () else (here := p; emit (C.Pos p))

      fun load x =
        case Array.sub (trees, x) of
          SOME (items, start, stop) =>
            (restore start; List.app emit (List.rev items); here := stop; Array.update (trees, x, NONE);
             pendingTrees := !pendingTrees - 1)
        | NONE =>
            (case Array.sub (defs, x) of
               SOME oper => if remat oper then operation oper else op' (Opcodes.LOCAL, [slotOf x])
             | NONE => op' (Opcodes.LOCAL, [slotOf x]))
      (* An operation: its operands pushed, and then it, where it was. *)
      and operation oper =
        let
          val p = !here
          fun op' (opc, args) = (restore p; emit (C.Op (opc, args)))
        in
        case oper of
          L.Const (Lambda.CInt i) =>
            if IntInf.>= (i, int32Min) andalso IntInf.<= (i, int32Max) then op' (Opcodes.INT, [IntInf.toInt i])
            else op' (Opcodes.CONST, [C.constIdx (Lambda.CInt i)])
        | L.Const c => op' (Opcodes.CONST, [C.constIdx c])
        | L.Unit => op' (Opcodes.UNIT, [])
        | L.Con0 t => op' (Opcodes.CON0, [t])
        | L.Global g => op' (Opcodes.GLOBAL, [C.globalIdx g])
        | L.SetGlobal (g, v) => (load v; op' (Opcodes.SETGLOBAL, [C.globalIdx g]))
        | L.Env i => op' (Opcodes.ENV, [i])
        | L.Self => op' (Opcodes.SELF, [])
        | L.Call (f, a) => (load f; load a; op' (Opcodes.CALL, []))
        | L.Prim (p, vs) => (List.app load vs; op' (Opcodes.PRIM, [C.primIdx p]))
        | L.Tuple vs => (List.app load vs; op' (Opcodes.TUPLE, [List.length vs]))
        | L.Select (i, v) => (load v; op' (Opcodes.SELECT, [i]))
        | L.Con (t, v) => (load v; op' (Opcodes.CON, [t]))
        | L.Decon v => (load v; op' (Opcodes.DECON, []))
        | L.ConTag v => (load v; op' (Opcodes.CONTAG, []))
        | L.NewExn n => op' (Opcodes.NEWEXN, [C.constIdx (Lambda.CString n)])
        | L.BuiltinExn k => op' (Opcodes.BUILTINEXN, [k])
        | L.MkExn (c, p) => (load c; load p; op' (Opcodes.MKEXN, []))
        | L.ExnCon v => (load v; op' (Opcodes.EXNCON, []))
        | L.ExnArg v => (load v; op' (Opcodes.EXNARG, []))
        | L.Closure (fid, vs) =>
            (List.app (fn SOME v => load v | NONE => op' (Opcodes.UNIT, [])) vs;
             op' (Opcodes.CLOSURE, [fid, List.length vs]))
        | L.SetEnv (c, i, v) => (load c; load v; op' (Opcodes.SETENV, [i]))
        end

      (* The code of a definition: a tree is kept for its use; a value
         stored, or dropped where nothing uses it. *)
      fun definition (x, oper) =
        if remat oper then ()
        else if isTree x then
          let
            val saved = !code
            val start = !here
            val () = code := []
            val () = operation oper
            val items = !code
            val stop = !here
          in
            code := saved; here := start; Array.update (trees, x, SOME (items, start, stop));
            pendingTrees := !pendingTrees + 1
          end
        else
          (operation oper;
           if usesOf x = 0 then (if pushes oper then op' (Opcodes.POP, []) else ())
           else
             (* SetGlobal and SetEnv leave nothing; what uses them wants () *)
             ((if pushes oper then () else op' (Opcodes.UNIT, []));
              op' (Opcodes.SETLOCAL, [slotOf x])))

      (* a jump to block i with arguments vs, from block `from` *)
      fun jump (from, l, vs) =
        let val i = target (blockIndex l)
        in
          if returnsParam i then (List.app load vs; op' (Opcodes.RET, []))
          else
            let
              val {params, ...} = Vector.sub (blocks, i)
              (* a parameter nothing reads is given nothing, where giving it
                 has no effect *)
              val moves = List.filter (fn (v, p) => not (usesOf p = 0 andalso isRemat v)) (ListPair.zip (vs, params))
            in
              List.app (load o #1) moves;
              List.app (fn (_, p) => if usesOf p = 0 then op' (Opcodes.POP, []) else op' (Opcodes.SETLOCAL, [slotOf p]))
                       (List.rev moves);
              if i = from + 1 then () else emit (C.OpLab (Opcodes.JUMP, labelOf i))
            end
        end

      fun branch (from, t, e, test) =
        let val ti = target (blockIndex t) val ei = target (blockIndex e)
        in
          if ei = from + 1 then emit (C.OpLab (if test = Opcodes.JUMPIFNOT then Opcodes.JUMPIF else test, labelOf ti))
          else (emit (C.OpLab (test, labelOf ei)); if ti = from + 1 then () else emit (C.OpLab (Opcodes.JUMP, labelOf ti)))
        end

      (* the blocks that are handlers *)
      val handlers : bool array = Array.array (Int.max (nblocks, 1), false)
      val () =
        Vector.app (fn ({instrs, ...} : L.block) =>
                      List.app (fn L.Push l => Array.update (handlers, blockIndex l, true) | _ => ()) instrs)
                   blocks
      fun block (i, {params, instrs, transfer, ...} : L.block) =
        let
          val handler = Array.sub (handlers, i)
        in
          emit (C.Lab (labelOf i));
          (* a handler's block begins with the exception on the stack *)
          if handler then
            (case params of
               [x] => if usesOf x = 0 then op' (Opcodes.POP, []) else op' (Opcodes.SETLOCAL, [slotOf x])
             | _ => bug "a handler's block of other than one parameter")
          else ();
          List.app (fn L.Def (x, oper) => definition (x, oper)
                     | L.Push l => emit (C.OpLab (Opcodes.PUSHHANDLER, labelOf (blockIndex l)))
                     | L.Pop => op' (Opcodes.POPHANDLER, [])
                     | L.At sp => at sp) instrs;
          case transfer of
            L.Goto (l, vs) => jump (i, l, vs)
          | L.If (v, t, e) => (load v; branch (i, t, e, Opcodes.JUMPIFNOT))
          | L.IfTag (v, tag, t, e) =>
              let val ti = target (blockIndex t) val ei = target (blockIndex e)
              in
                load v;
                emit (C.OpLabImm (Opcodes.JUMPIFNOTTAG, labelOf ei, tag));
                if ti = i + 1 then () else emit (C.OpLab (Opcodes.JUMP, labelOf ti))
              end
          | L.Return v => (load v; op' (Opcodes.RET, []))
          | L.TailCall (fv, a) => (load fv; load a; op' (Opcodes.TAILCALL, []))
          | L.Raise v => (load v; op' (Opcodes.RAISE, []))
        end
      val () = Vector.appi block blocks
      val () = if !pendingTrees = 0 then () else bug "a tree never used"
    in
      {id = #id f, nlocals = !nslots, code = List.rev (!code), name = #name f}
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
