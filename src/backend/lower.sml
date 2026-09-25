(* From Mid to Low (docs/ir.md): each function of Mid becomes a function of
   Low, and closures become explicit on the way (closure conversion). A
   function captures the variables free in it, in the order of their stamps,
   less itself, which it reads as `Self`; the members of a group made
   together capture each other, and those not made yet are set after
   (`SetEnv`): flat closures.

   A join point becomes a block with its parameters; a Handle a Push, the
   blocks of its body, and the handler's block, whose parameter is the
   exception; a jump or a return out of a handler's region pops what it
   leaves. A variable bound to another is the other (no copy), and one
   bound to a constant, a global or a captured value is read again where
   it is used. A match against a constructor's tag -- ConTag, poly_eq with
   the tag, If -- is one IfTag, and a chain of three or more of the same
   value, each in the other's else, one Switch.

   A call of a function of the top level is a known call (CallK), which
   passes no closure, since such a function captures nothing and names
   itself as the global it is; its arguments are as many as its
   parameters. A function of other than one parameter is only ever called
   so, and is made no closure.

   A call of a function of itself in tail position, where no handler is
   pushed, is a jump back to its head: a block after the entry whose
   parameters are the function's, so that the function is a loop -- the
   only edge of Low that goes backward. *)
structure Lower =
struct
  structure M = Mid
  structure L = Low

  fun bug msg = Error.bug ("Lower: " ^ msg)

  (* ---- what the whole program says ---- *)

  (* How many times each variable is used, and what each function captures,
     by its name. *)
  val useCounts : int IntMap.map ref = ref IntMap.empty
  val captures : int list IntMap.map ref = ref IntMap.empty
  val selfRefs : bool IntMap.map ref = ref IntMap.empty

  fun count x = useCounts := IntMap.insert (!useCounts, x, 1 + (case IntMap.find (!useCounts, x) of SOME n => n | NONE => 0))
  fun usesOf x = case IntMap.find (!useCounts, x) of SOME n => n | NONE => 0

  fun countAtom a = case a of M.Var (x, _) => count x | _ => ()
  fun countRhs r =
    case r of
      M.Atom a => countAtom a
    | M.App (f, xs) => List.app countAtom (f :: xs)
    | M.Prim (_, _, xs) => List.app countAtom xs
    | M.Tuple xs => List.app countAtom xs
    | M.Select (_, a) => countAtom a
    | M.Con (_, _, a) => countAtom a
    | M.Decon (_, a) => countAtom a
    | M.ConTag a => countAtom a
    | M.MkExn (c, a) => (countAtom c; countAtom a)
    | M.ExnCon a => countAtom a
    | M.ExnArg (_, a) => countAtom a
    | M.SetGlobal (_, a) => countAtom a
    | _ => ()

  (* The free variables of e, those in bound left out, added to acc; each
     function's are worked out once (captures). *)
  fun free (e : M.exp, bound : unit IntMap.map, acc : unit IntMap.map) : unit IntMap.map =
    let
      fun atom (a, acc) =
        case a of
          M.Var (x, _) => if IntMap.member (bound, x) then acc else IntMap.insert (acc, x, ())
        | _ => acc
      fun atoms (xs, acc) = List.foldl atom acc xs
      fun rhs (r, acc) =
        case r of
          M.Atom a => atom (a, acc)
        | M.App (f, xs) => atoms (f :: xs, acc)
        | M.Prim (_, _, xs) => atoms (xs, acc)
        | M.Tuple xs => atoms (xs, acc)
        | M.Select (_, a) => atom (a, acc)
        | M.Con (_, _, a) => atom (a, acc)
        | M.Decon (_, a) => atom (a, acc)
        | M.ConTag a => atom (a, acc)
        | M.MkExn (c, a) => atoms ([c, a], acc)
        | M.ExnCon a => atom (a, acc)
        | M.ExnArg (_, a) => atom (a, acc)
        | M.SetGlobal (_, a) => atom (a, acc)
        | _ => acc
      fun bind (x, b) = IntMap.insert (b, x, ())
    in
      case e of
        M.Let (x, _, r, b) => free (b, bind (x, bound), rhs (r, acc))
      | M.Fun (fs, b) =>
          let
            val bound' = List.foldl (fn (f, m) => bind (#name f, m)) bound fs
            val acc = List.foldl (fn (f, acc) =>
                                     List.foldl (fn (x, acc) => if IntMap.member (bound', x) then acc else IntMap.insert (acc, x, ()))
                                                acc (capturesOf f)) acc fs
          in free (b, bound', acc) end
      | M.Join (_, ps, body, s) =>
          free (s, bound, free (body, List.foldl (fn ((x, _), m) => bind (x, m)) bound ps, acc))
      | M.Jump (_, xs) => atoms (xs, acc)
      | M.If (c, t, f) => free (f, bound, free (t, bound, atom (c, acc)))
      | M.Handle (a, x, h) => free (h, bind (x, bound), free (a, bound, acc))
      | M.Raise a => atom (a, acc)
      | M.Return r => rhs (r, acc)
      | M.Mark (_, a) => free (a, bound, acc)
    end

  (* What a function captures: the variables free in it, but itself, in the
     order of their stamps; its siblings of a group are among them. Whether
     it names itself is found on the same walk (selfRefs). *)
  and capturesOf (f : M.fundef) : int list =
    case IntMap.find (!captures, #name f) of
      SOME cs => cs
    | NONE =>
        let
          val bound = List.foldl (fn ((x, _), m) => IntMap.insert (m, x, ())) IntMap.empty (#params f)
          val fv = free (#body f, bound, IntMap.empty)
          val self = IntMap.member (fv, #name f)
          val cs = IntMap.listKeys (if self then IntMap.remove (fv, #name f) else fv)
        in
          captures := IntMap.insert (!captures, #name f, cs);
          selfRefs := IntMap.insert (!selfRefs, #name f, self);
          cs
        end

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

  (* ---- the functions being made ---- *)

  val funcs : L.func list ref = ref []
  val nextFuncId = ref 0
  val funNames : string IntMap.map ref = ref IntMap.empty

  (* The functions of the top level, by their globals: known ones, and the
     id each is made with, which a known call made before it is given at
     the end (resolve). *)
  val knownFuns : unit IntMap.map ref = ref IntMap.empty
  val globalFids : int IntMap.map ref = ref IntMap.empty
  fun isKnown g = IntMap.member (!knownFuns, g)

  (* A function being made: its blocks so far, the block being filled, and
     how it reads the variables it captures. *)
  type builder = {blocks : L.block list ref, label : L.label ref, params : L.var list ref, instrs : L.instr list ref,
                  open' : bool ref, nextLabel : int ref, nvars : int ref, env : int IntMap.map, self : int option,
                  span : Source.span option ref, head : L.label option ref}

  fun newLabel (b : builder) = let val l = !(#nextLabel b) in #nextLabel b := l + 1; l end
  (* a variable of Low: numbered from 0 in each function, so that a target
     keeps what it knows of them in arrays *)
  fun newVar (b : builder) = let val v = !(#nvars b) in #nvars b := v + 1; v end
  fun emit (b : builder, i) = if !(#open' b) then #instrs b := i :: !(#instrs b) else ()
  fun def (b : builder, oper) = let val x = newVar b in emit (b, L.Def (x, oper)); x end
  fun finish (b : builder, t : L.transfer) =
    if !(#open' b) then
      (#blocks b := {label = !(#label b), params = !(#params b), instrs = List.rev (!(#instrs b)), transfer = t}
                    :: !(#blocks b);
       #open' b := false)
    else ()
  fun start (b : builder, l, params) =
    (if !(#open' b) then bug "a block started before the last was finished" else ();
     #label b := l; #params b := params; #instrs b := []; #open' b := true)

  (* Where the value of an expression goes: returned from the function, to a
     block (as its parameter) with the handlers pushed when it was made, or
     to what follows it in the same block. *)
  datatype ret = FunRet | ToBlock of L.label * int | Cont of L.var -> unit

  (* What an expression is lowered in: where its value goes, how many
     handlers the function has pushed, its join points (with the handlers
     pushed where each was made), and the variable of Low each variable of
     Mid bound in the function is. *)
  type cx = {ret : ret, depth : int, labels : (L.label * int) IntMap.map, subst : L.var IntMap.map}

  fun bindAs ({ret, depth, labels, subst} : cx, x : int, v : L.var) : cx =
    {ret = ret, depth = depth, labels = labels, subst = IntMap.insert (subst, x, v)}

  (* An expression with one way out, and that at its end: its value can go
     on in the same block. *)
  fun straight (e : M.exp) : bool =
    case e of
      M.Let (_, _, _, b) => straight b
    | M.Fun (_, b) => straight b
    | M.Mark (_, a) => straight a
    | M.Return _ => true
    | _ => false

  val int32Max : IntInf.int = IntInf.fromInt 1073741823
  val int32Min : IntInf.int = IntInf.fromInt ~1073741824

  (* Whether f calls itself in tail position of its body, where no handler
     is pushed: the calls a loop makes of it. *)
  fun loops (f : M.fundef) : bool =
    let
      fun self (M.Global (g, _)) = g = #name f andalso isKnown g
        | self (M.Var (x, _)) = x = #name f
        | self _ = false
      fun tail e =
        case e of
          M.Let (_, _, _, b) => tail b
        | M.Fun (_, b) => tail b
        | M.Join (_, _, body, s) => tail body orelse tail s
        | M.If (_, t, e) => tail t orelse tail e
        | M.Handle (_, _, h) => tail h      (* its body is no tail position *)
        | M.Return (M.App (g, xs)) => self g andalso List.length xs = List.length (#params f)
        | M.Mark (_, a) => tail a
        | _ => false
    in tail (#body f) end

  (* ---- lowering ---- *)

  fun function (f : M.fundef, pos : Source.span option, group : int) : int =
    let
      val id = !nextFuncId
      val () = nextFuncId := id + 1
      val cs = capturesOf f
      val param = case #params f of (x, _) :: _ => x | [] => bug "a function of no parameter"
      val recursive = group > 1 orelse IntMap.find (!selfRefs, #name f) = SOME true
      val name =
        case IntMap.find (!funNames, param) of
          SOME n => n
        | NONE => if recursive then "fn" ^ Int.toString (#name f) else "fn"
      val b : builder = {blocks = ref [], label = ref 0, params = ref [], instrs = ref [], open' = ref false,
                         nextLabel = ref 0, nvars = ref 0,
                         env = #1 (List.foldl (fn (x, (m, i)) => (IntMap.insert (m, x, i), i + 1)) (IntMap.empty, 0) cs),
                         self = SOME (#name f), span = ref pos, head = ref NONE}
      val ps = List.map (fn (x, _) => (x, newVar b)) (#params f)
      val () = start (b, newLabel b, [])
      (* a loop: the entry jumps to the head, whose parameters the body
         reads, and which the calls of the loop jump back to *)
      val bound =
        if loops f then
          let
            val l = newLabel b
            val hs = List.map (fn (x, _) => (x, newVar b)) ps
          in
            finish (b, L.Goto (l, List.map #2 ps)); start (b, l, List.map #2 hs); #head b := SOME l; hs
          end
        else ps
      val () = exp (b, #body f, {ret = FunRet, depth = 0, labels = IntMap.empty,
                                 subst = List.foldl (fn ((x, v), m) => IntMap.insert (m, x, v)) IntMap.empty bound})
    in
      funcs := {id = id, name = name, params = List.map #2 ps, ncaptured = List.length cs, nvars = !(#nvars b),
                blocks = List.rev (!(#blocks b)), pos = pos} :: !funcs;
      id
    end

  (* The variable an atom's value is in, made here where it is a constant,
     a global or a captured value. *)
  and atom (b : builder, cx : cx, a : M.atom) : L.var =
    case a of
      M.Var (x, _) => var (b, cx, x)
    | M.Global (g, _) => def (b, L.Global g)
    | M.Const (c, _) => def (b, L.Const c)
    | M.Con0 (tag, _) => def (b, L.Con0 tag)
    | M.Unit => def (b, L.Unit)

  and var (b : builder, cx : cx, x : int) : L.var =
    case IntMap.find (#subst cx, x) of
      SOME y => y
    | NONE =>
        case IntMap.find (#env b, x) of
          SOME i => def (b, L.Env i)
        | NONE => if #self b = SOME x then def (b, L.Self) else bug ("v" ^ Int.toString x ^ " is not in scope")

  and oper (b : builder, cx : cx, r : M.rhs) : L.operation =
    let fun at a = atom (b, cx, a)
    in
      case r of
        M.Atom _ => bug "an atom as an operation"
      | M.App (M.Global (g, _), xs) => if isKnown g then L.CallK (g, List.map at xs) else unknown (b, cx, r)
      | M.App _ => unknown (b, cx, r)
      | M.Prim (p, _, xs) => L.Prim (p, List.map at xs)
      | M.Tuple xs => L.Tuple (List.map at xs)
      | M.Select (i, a) => L.Select (i, at a)
      | M.Con (tag, _, a) => L.Con (tag, at a)
      | M.Decon (tag, a) => L.Decon (tag, at a)
      | M.ConTag a => L.ConTag (at a)
      | M.NewExn n => L.NewExn n
      | M.BuiltinExn k => L.BuiltinExn k
      | M.MkExn (c, a) => let val c = at c in L.MkExn (c, at a) end
      | M.ExnCon a => L.ExnCon (at a)
      | M.ExnArg (_, a) => L.ExnArg (at a)
      | M.SetGlobal (g, a) => L.SetGlobal (g, at a)
    end

  (* a call through a closure, of one argument *)
  and unknown (b, cx, r : M.rhs) : L.operation =
    case r of
      M.App (f, [a]) => let val f = atom (b, cx, f) in L.Call (f, atom (b, cx, a)) end
    | _ => bug "a call of other than one argument through a closure"

  and value (b, cx, r : M.rhs) : L.var =
    case r of
      M.Atom a => atom (b, cx, a)
    | _ => def (b, oper (b, cx, r))

  and pops (b, n) = if n <= 0 then () else (emit (b, L.Pop); pops (b, n - 1))

  (* Lower e into the block being filled, which it finishes, but for a Cont,
     whose rest fills it on. *)
  and exp (b : builder, e : M.exp, cx : cx) : unit =
    case e of
      M.Let (x, _, r, body) =>
        (case tagTest (x, r, body) of
           SOME (y, tag, sp, t, f) =>
             (case switchOf (y, [(tag, sp, t)], f) of
                SOME (cases, (dsp, d)) =>
                  let
                    val v = var (b, cx, y)
                    val ls = List.map (fn c => (c, newLabel b)) cases
                    val ld = newLabel b
                    fun at sp = case sp of SOME s => emit (b, L.At s) | NONE => ()
                  in
                    finish (b, L.Switch (v, List.map (fn ((tag, _, _), l) => (tag, l)) ls, ld));
                    List.app (fn ((_, sp, t), l) => (start (b, l, []); at sp; exp (b, t, cx))) ls;
                    start (b, ld, []); at dsp; exp (b, d, cx)
                  end
              | NONE =>
                  let
                    val v = var (b, cx, y)
                    val lt = newLabel b
                    val lf = newLabel b
                  in
                    finish (b, L.IfTag (v, tag, lt, lf));
                    start (b, lt, []); (case sp of SOME s => emit (b, L.At s) | NONE => ()); exp (b, t, cx);
                    start (b, lf, []); (case sp of SOME s => emit (b, L.At s) | NONE => ()); exp (b, f, cx)
                  end)
         | NONE =>
             (case r of
                M.Atom a => exp (b, body, bindAs (cx, x, atom (b, cx, a)))
              | _ => exp (b, body, bindAs (cx, x, def (b, oper (b, cx, r))))))
    | M.Fun (fs, body) => exp (b, body, closures (b, cx, fs))
    | M.Join (j, ps, jbody, scope) =>
        let val l = newLabel b
        in
          exp (b, scope, {ret = #ret cx, depth = #depth cx, labels = IntMap.insert (#labels cx, j, (l, #depth cx)),
                          subst = #subst cx});
          let val vs = List.map (fn _ => newVar b) ps
          in
            start (b, l, vs);
            exp (b, jbody, ListPair.foldl (fn ((x, _), v, cx) => bindAs (cx, x, v)) cx (ps, vs))
          end
        end
    | M.Jump (j, xs) =>
        (case IntMap.find (#labels cx, j) of
           SOME (l, d) =>
             let val vs = List.map (fn a => atom (b, cx, a)) xs
             in pops (b, #depth cx - d); finish (b, L.Goto (l, vs)) end
         | NONE => bug "a jump to a join point not in scope")
    | M.If (c, t, f) =>
        let
          val v = atom (b, cx, c)
          val lt = newLabel b
          val lf = newLabel b
        in
          finish (b, L.If (v, lt, lf));
          start (b, lt, []); exp (b, t, cx);
          start (b, lf, []); exp (b, f, cx)
        end
    | M.Handle (a, x, h) =>
        let val lh = newLabel b
        in
          emit (b, L.Push lh);
          exp (b, a, {ret = #ret cx, depth = #depth cx + 1, labels = #labels cx, subst = #subst cx});
          let val v = newVar b
          in start (b, lh, [v]); exp (b, h, bindAs (cx, x, v)) end
        end
    | M.Raise a => let val v = atom (b, cx, a) in finish (b, L.Raise v) end
    | M.Return r =>
        (case (#ret cx, r) of
           (FunRet, M.App (f, xs)) =>
             (case (#depth cx, !(#head b), f) of
                (0, SOME l, M.Global (g, _)) =>
                  if #self b = SOME g then finish (b, L.Goto (l, List.map (fn a => atom (b, cx, a)) xs))
                  else knownTail (b, cx, r)
              | (0, SOME l, M.Var (x, _)) =>
                  if #self b = SOME x andalso not (IntMap.member (#subst cx, x)) then
                    finish (b, L.Goto (l, List.map (fn a => atom (b, cx, a)) xs))
                  else knownTail (b, cx, r)
              | _ => knownTail (b, cx, r))
         | (FunRet, _) => let val v = value (b, cx, r) in pops (b, #depth cx); finish (b, L.Return v) end
         | (ToBlock (l, d), _) => let val v = value (b, cx, r) in pops (b, #depth cx - d); finish (b, L.Goto (l, [v])) end
         | (Cont k, _) => k (value (b, cx, r)))
    | M.Mark (sp, a) => (emit (b, L.At sp); #span b := SOME (#1 sp); exp (b, a, cx))

  (* a call in tail position of the function: a known tail call, where no
     handler is pushed, of a function of the top level *)
  and knownTail (b, cx, r : M.rhs) =
    case r of
      M.App (M.Global (g, _), xs) =>
        if #depth cx = 0 andalso isKnown g then finish (b, L.TailCallK (g, List.map (fn a => atom (b, cx, a)) xs))
        else tailCall (b, cx, r)
    | _ => tailCall (b, cx, r)

  (* one through a closure: a tail call where no handler is pushed *)
  and tailCall (b, cx, r : M.rhs) =
    case (#depth cx, r) of
      (0, M.App (f, [a])) => let val f = atom (b, cx, f) in finish (b, L.TailCall (f, atom (b, cx, a))) end
    | _ => let val v = value (b, cx, r) in pops (b, #depth cx); finish (b, L.Return v) end

  (* ConTag of y, poly_eq of it with a tag, and an If on that, each used
     once: y, the tag, and the two branches. *)
  and tagTest (x, r, body) =
    case r of
      M.ConTag (M.Var (y, _)) =>
        if usesOf x <> 1 then NONE
        else
          let
            fun unmark (M.Mark (sp, e), _) = unmark (e, SOME sp)
              | unmark (e, sp) = (e, sp)
          in
            case unmark (body, NONE) of
              (M.Let (c, _, M.Prim ("poly_eq", _, [M.Var (x', _), M.Const (Lambda.CInt i, _)]), rest), sp1) =>
                if x' = x andalso usesOf c = 1 andalso IntInf.>= (i, int32Min) andalso IntInf.<= (i, int32Max) then
                  (case unmark (rest, sp1) of
                     (M.If (M.Var (c', _), t, f), sp2) =>
                       if c' = c then SOME (y, IntInf.toInt i, sp2, t, f) else NONE
                   | _ => NONE)
                else NONE
            | _ => NONE
          end
    | _ => NONE

  (* The tests of y's tag that follow in the else of each other, from the
     one found: each tag, where it was and what it goes to -- a tag tested
     again is left out, since the else of its first test is where the value
     has another -- and the rest, with where it was; where they are three
     or more, and a table of their tags no more than about four times as
     big, a Switch. *)
  and switchOf (y, found, f) =
    let
      fun peel (M.Mark (sp, e), _) = peel (e, SOME sp)
        | peel (e, sp) = (e, sp)
      fun collect (acc, f, fsp) =
        case peel (f, fsp) of
          (M.Let (x, _, r, body), sp) =>
            (case tagTest (x, r, body) of
               SOME (y', tag, sp', t, f') =>
                 if y' <> y then (List.rev acc, (sp, f))
                 else if List.exists (fn (t', _, _) => t' = tag) acc then collect (acc, f', sp')
                 else collect ((tag, sp', t) :: acc, f', sp')
             | NONE => (List.rev acc, (sp, f)))
        | (e, sp) => (List.rev acc, (sp, e))
      val (cases, rest) = collect (List.rev found, f, NONE)
      val n = List.length cases
      val top = List.foldl (fn ((t, _, _), m) => Int.max (t, m)) 0 cases
    in
      if n >= 3 andalso top < 4 * n + 8 then SOME (cases, rest) else NONE
    end

  (* The closures of a group of functions: each made in turn, capturing
     those made before it and a placeholder for those after, which are set
     once all are made; the context with their names bound to them. *)
  and closures (b : builder, cx : cx, fs : M.fundef list) : cx =
    let
      (* a function begins where it is made, so that what comes before the
         first position of its body is not put down to what was made before *)
      val pos = !(#span b)
      fun go ([], cx, patches) = (cx, patches)
        | go (f :: rest, cx, patches) =
            let
              val fid = function (f, pos, List.length fs)
              val later = List.map #name rest
              val cs = capturesOf f
              val (vs, ps, _) =
                List.foldl (fn (c, (vs, ps, i)) =>
                              if List.exists (fn l => l = c) later then (NONE :: vs, (#name f, i, c) :: ps, i + 1)
                              else (SOME (var (b, cx, c)) :: vs, ps, i + 1))
                           ([], [], 0) cs
              val v = def (b, L.Closure (fid, List.rev vs))
            in go (rest, bindAs (cx, #name f, v), patches @ List.rev ps) end
      val (cx, patches) = go (fs, cx, [])
    in
      List.app (fn (f, i, c) => ignore (def (b, L.SetEnv (var (b, cx, f), i, var (b, cx, c))))) patches;
      cx
    end

  (* ---- the program ---- *)

  (* The ids of the functions known calls call, now that each has one. *)
  fun resolve (f : L.func) : L.func =
    let
      fun fid g = case IntMap.find (!globalFids, g) of SOME i => i | NONE => bug "a known call of no function"
      fun instr (L.Def (x, L.CallK (g, vs))) = L.Def (x, L.CallK (fid g, vs))
        | instr i = i
      fun block ({label, params, instrs, transfer} : L.block) : L.block =
        {label = label, params = params, instrs = List.map instr instrs,
         transfer = case transfer of L.TailCallK (g, vs) => L.TailCallK (fid g, vs) | t => t}
      val {id, name, params, ncaptured, nvars, blocks, pos} = f
    in
      {id = id, name = name, params = params, ncaptured = ncaptured, nvars = nvars, blocks = List.map block blocks,
       pos = pos}
    end

  fun program (p : M.program, names : string IntMap.map) : L.program =
    let
      val () = (useCounts := IntMap.empty; captures := IntMap.empty; selfRefs := IntMap.empty; funcs := [];
                nextFuncId := 0; funNames := names; globalFids := IntMap.empty;
                knownFuns := List.foldl (fn (M.Funs fs, m) => List.foldl (fn (f, m) => IntMap.insert (m, #name f, ())) m fs
                                          | (_, m) => m) IntMap.empty p)
      val () = List.app (fn M.Val (_, _, e) => countExp e
                          | M.Funs fs => List.app (countExp o #body) fs
                          | M.Do (_, e) => countExp e) p
      val id = !nextFuncId
      val () = nextFuncId := id + 1
      val b : builder = {blocks = ref [], label = ref 0, params = ref [], instrs = ref [], open' = ref false,
                         nextLabel = ref 0, nvars = ref 0, env = IntMap.empty, self = NONE, span = ref NONE,
                         head = ref NONE}
      val param = newVar b
      val () = start (b, newLabel b, [])
      val top : cx = {ret = FunRet, depth = 0, labels = IntMap.empty, subst = IntMap.empty}
      (* a definition's expression, whose value then goes to k *)
      fun defining (e, k : L.var -> unit) =
        if straight e then exp (b, e, {ret = Cont k, depth = 0, labels = IntMap.empty, subst = IntMap.empty})
        else
          let
            val l = newLabel b
            val x = newVar b
          in
            exp (b, e, {ret = ToBlock (l, 0), depth = 0, labels = IntMap.empty, subst = IntMap.empty});
            start (b, l, [x]);
            k x
          end
      fun definition d =
        case d of
          M.Val (g, _, e) => defining (e, fn v => ignore (def (b, L.SetGlobal (g, v))))
        | M.Funs fs =>
            List.app (fn f =>
                        let val fid = function (f, !(#span b), 1)
                        in
                          if null (capturesOf f) then ()
                          else bug "a global function that captures a variable";
                          globalFids := IntMap.insert (!globalFids, #name f, fid);
                          case #params f of
                            [_] => ignore (def (b, L.SetGlobal (#name f, def (b, L.Closure (fid, [])))))
                          | _ => ()
                        end) fs
        | M.Do (_, e) => defining (e, fn _ => ())
      val () = List.app definition p
      val u = def (b, L.Unit)
      val () = finish (b, L.Return u)
      val () = ignore top
      val topFunc : L.func = {id = id, name = "<toplevel>", params = [param], ncaptured = 0, nvars = !(#nvars b),
                              blocks = List.rev (!(#blocks b)), pos = NONE}
    in
      IntMap.listItems (List.foldl (fn (f : L.func, m) => IntMap.insert (m, #id f, resolve f)) IntMap.empty
                                   (topFunc :: !funcs))
    end
end
