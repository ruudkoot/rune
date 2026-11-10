(* From Mid to Low (docs/ir.md): each function of Mid becomes a function of
   Low, and closures become explicit on the way (closure conversion). A
   function captures the variables free in what is made of it, in the
   order of their stamps, less itself, which it reads as `Self`; the members
   of a group made together capture each other, and those not made yet are
   set after (`SetEnv`): flat closures.

   A join point becomes a block with its parameters; a Handle a Push, the
   blocks of its body, and the handler's block, whose parameter is the
   exception; a jump or a return out of a handler's region pops what it
   leaves. A variable bound to another is the other (no copy), and one
   bound to a constant, a global or a captured value is read again where
   it is used. A match against a constructor's tag -- ConTag, poly_eq or
   imm_eq with the tag, If -- is one IfTag, and a chain of three or more of the same
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
  open Results

  fun bug msg = Error.bug ("Lower: " ^ msg)

  (* ---- what the whole program says ---- *)

  (* How many times each variable is used, and what each function captures,
     by its name. *)
  val captures : int list IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.captures", captures)
  val selfRefs : bool IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.selfRefs", selfRefs)

  (* What the code made of the program declares, from the types, for a
     check of it (RegVerify; docs/plans/correctness/linting.md, D9): what
     each global holds, by its stamp -- any where the program does not say,
     or where results share it (slotsOf, sumsOf) -- and where each closure is
     made: the function that makes it, and what it captures (Low.Closure),
     whose representations there are what the closure's slots hold. *)
  val globalReps : L.rep IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.globalReps", globalReps)
  val closureSites : (int * L.var option list) IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.closureSites", closureSites)

  (* A variable whose value is not made where it is bound (M11): a tuple
     used once, whose parts a constructor made of its fields, or a field
     taken of it, uses as they are (Parts); or the argument of a constructor
     value made of its fields, each of whose uses takes a field (Fields: the
     tag, the number of fields, the value). A use that needs it whole makes
     it there (var). Its parts are variables of the function that binds it,
     whose id it is kept with: a function that captures it reads it whole
     from its closure, made where the closure is. *)
  datatype virt = Parts of L.var list | Fields of int * int * L.var | Sum of L.var * L.var list
  val virtuals : (int * virt) IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Lower.virtuals", virtuals, IntTable.copy)

  val int32Max : IntInf.int = IntInf.fromInt 1073741823
  val int32Min : IntInf.int = IntInf.fromInt ~1073741824

  (* ConTag of y, poly_eq of it with a tag -- or imm_eq, which the
     simplifier makes of it -- and an If on that, each used once: y, the
     tag, and the two branches. *)
  fun tagTest (x, r, body) =
    case r of
      M.ConTag (M.Var (y, _)) =>
        if usesOf x <> 1 then NONE
        else
          let
            fun unmark (M.Mark (sp, e), _) = unmark (e, SOME sp)
              | unmark (e, sp) = (e, sp)
          in
            case unmark (body, NONE) of
              (M.Let (c, _, M.Prim (eq, _, [M.Var (x', _), M.Const (Literal.CInt i, _)]), rest), sp1) =>
                if (eq = "poly_eq" orelse eq = "imm_eq") andalso x' = x andalso usesOf c = 1 andalso IntInf.>= (i, int32Min) andalso IntInf.<= (i, int32Max) then
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
  fun switchOf (y, found, f) =
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

  (* The free variables of e, those in bound left out, added to acc; each
     function's are worked out once (captures). They are those of the code
     Lower makes of it, so that a closure captures nothing its function
     never reads: a Switch leaves out the branch of a tag tested again. *)
  fun free (e : M.exp, bound0 : unit IntMap.map, acc : unit IntMap.map) : unit IntMap.map =
    let
      (* what is bound, in one table for the walk: each variable is bound
         once, so one bound in a branch is used in no other *)
      val bound : unit IntTable.table = IntTable.table 64
      val () = IntMap.appi (fn (x, ()) => IntTable.insert (bound, x, ())) bound0
      fun isBound x = isSome (IntTable.find (bound, x))
      fun var (x, acc) = if isBound x then acc else IntMap.insert (acc, x, ())
      fun atom (a, acc) =
        case a of
          M.Var (x, _) => var (x, acc)
        | _ => acc
      fun atoms (xs, acc) = List.foldl atom acc xs
      fun rhs (r, acc) = M.foldAtomsOfRhs atom acc r
      fun bind x = IntTable.insert (bound, x, ())
      fun go (e, acc) =
        case e of
          M.Let (x, _, r, b) =>
            (case tagTest (x, r, b) of
               SOME (y, tag, sp, t, f) =>
                 (case switchOf (y, [(tag, sp, t)], f) of
                    SOME (cases, (_, d)) => go (d, List.foldl (fn ((_, _, t), acc) => go (t, acc)) (var (y, acc)) cases)
                  | NONE => go (f, go (t, var (y, acc))))
             | NONE =>
                 (* a tuple or a constructor nothing uses is not made (exp,
                    below): what it would hold is not read *)
                 let val acc = if usesOf x = 0 andalso (case r of M.Tuple (_ :: _) => true | M.Con _ => true | _ => false)
                               then acc else rhs (r, acc)
                 in bind x; go (b, acc) end)
        | M.Fun (fs, b) =>
            (List.app (fn f => bind (#name f)) fs;
             go (b, List.foldl (fn (f, acc) =>
                                  List.foldl (fn (x, acc) => if isBound x then acc else IntMap.insert (acc, x, ()))
                                             acc (capturesOf f)) acc fs))
        | M.Join (_, ps, body, s) => (List.app (fn (x, _) => bind x) ps; go (s, go (body, acc)))
        | M.Jump (_, xs) => atoms (xs, acc)
        | M.If (c, t, f) => go (f, go (t, atom (c, acc)))
        | M.Handle (a, x, h) => let val acc = go (a, acc) in bind x; go (h, acc) end
        | M.Raise a => atom (a, acc)
        | M.Return r => rhs (r, acc)
        | M.Mark (_, a) => go (a, acc)
    in
      go (e, acc)
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

  (* ---- the functions being made ---- *)

  val funcs : L.func list ref = ref []
  val () = CompilerState.cellRoot ("Lower.funcs", funcs)
  val nextFuncId = ref 0
  val () = CompilerState.cellRoot ("Lower.nextFuncId", nextFuncId)
  val () = Pass.counter nextFuncId

  (* The functions of the top level, by their globals: known ones, and the
     id each is made with, which a known call made before it is given at
     the end (resolve). *)
  val knownFuns : unit IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.knownFuns", knownFuns)
  val globalFids : int IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.globalFids", globalFids)
  fun isKnown g = IntMap.member (!knownFuns, g)

  (* A unit (not Pass.whole; docs/plans/incremental-compilation.md, M2):
     the functions of the top level of the units before it, which a known
     call may call too, by their globals; and those this unit calls, each
     by the id it is given here, after the unit's own functions, which the
     linker replaces (Link). A unit's top level ends in a tail call of the
     next unit's, by the stamp nextUnit. *)
  val knownBefore : unit IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.knownBefore", knownBefore)
  val imported : int IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Lower.imported", imported)
  val nextUnit = ~1

  (* A function being made: its id, its blocks so far, the block being
     filled, and how it reads the variables it captures. *)
  type builder = {fid : int, blocks : L.block list ref, label : L.label ref, params : L.var list ref, instrs : L.instr list ref,
                  open' : bool ref, nextLabel : int ref, nvars : int ref, env : int IntTable.table, self : int option,
                  span : Source.span option ref, head : L.label option ref,
                  reps : L.rep IntTable.table,   (* what each variable holds, where known (RAny otherwise) *)
                  tys : Ty.ty option array ref}  (* each variable's Mid type, where kept and known (keepTys) *)

  (* The Mid type of each Low variable where Lower knows it, by function id,
     of the program last lowered, for the check of shapes (LowShapes; the
     linting roadmap's D14 and M6): kept where that check runs, from level 1
     of the lint (keepTys, which Lower.program sets), so that a compile
     that does not check pays nothing for them. A variable defAny made, of
     more than one type on purpose, has none; nor has one whose first type
     another gave (setTy), as with its representation. *)
  val lastTys : Ty.ty option array ref IntTable.table ref = ref (IntTable.table 1)
  (* a ref of a table, as the state's audit has it (tools/compiler): the
     table copied, its arrays shared, which only the lowering of one program
     and the check of it after read *)
  val () = CompilerState.refRoot ("Lower.lastTys", lastTys, IntTable.copy)
  val keepTys = ref false
  val () = CompilerState.cellRoot ("Lower.keepTys", keepTys)
  (* whether the shapes will be checked, which LowShapes sets *)
  val shapesChecked : (unit -> bool) ref = ref (fn () => false)
  val () = CompilerState.cellRoot ("Lower.shapesChecked", shapesChecked)

  (* The representation of a value of a type (Low.rep): the built-in types
     by their names; a datatype by its constructors (nullary only: a
     T_CON0; none nullary: in the heap; both: either); a tuple, a
     function, an exception in the heap; a type variable any. *)
  (* open_layout's descriptor (docs/ir.md, Open constructors): the fields the
     constructor tag of the datatype its type takes is laid out in, 0 where
     it boxes its argument, by the datatype's layout now (Ty.layoutOf), after
     the expansion decided it *)
  fun openLayout (t : Ty.ty, tag : int) : int =
    case Ty.view t of
      Ty.Arrow (d, _) =>
        (case Ty.view d of
           Ty.Con (s, _, _) =>
             (case List.find (fn (t', _) => t' = tag) (Ty.layoutOf s) of
                SOME (_, SOME n) =>
                  if n > Ty.maxFlat then bug ("open_layout: " ^ Int.toString n ^ " fields, more than a descriptor gives")
                  else n
              | _ => 0)
         | _ => bug "open_layout of what is no datatype")
    | _ => bug "open_layout of no function type"

  fun repOfTy (t : Ty.ty) : L.rep =
    case Ty.view t of
      Ty.Tuple [] => L.RUnit
    | Ty.Tuple _ => L.RPtr
    | Ty.Arrow _ => L.RPtr
    | Ty.ExnCon => L.RPtr
    | Ty.Gen _ => L.RAny
    | Ty.Var _ => L.RAny
    (* a type variable applied: what it stands for is not known here *)
    | Ty.App _ => L.RAny
    (* a polymorphic field's value is its body's: no type is passed *)
    | Ty.Forall (_, b) => repOfTy b
    | Ty.Con (stamp, name, _) =>
        if stamp = #stamp Types.intTycon then L.RInt
        else if stamp = #stamp Types.wordTycon then L.RWord
        else if stamp = #stamp Types.int64Tycon then L.RInt64
        else if stamp = #stamp Types.word64Tycon then L.RWord64
        else if stamp = #stamp Types.realTycon then L.RReal
        else if stamp = #stamp Types.charTycon then L.RChar
        else if stamp = #stamp Types.stringTycon then L.RPtr
        else if stamp = #stamp Types.bytearrayTycon then L.RPtr
        else if stamp = #stamp Types.realarrayTycon then L.RPtr
        else if stamp = #stamp Types.exnTycon then L.RPtr
        else
          case Ty.datatypeOf stamp of
            SOME {cons, ...} =>
              let
                val nullary = List.exists (fn (_, _, NONE) => true | _ => false) cons
                val withArg = List.exists (fn (_, _, SOME _) => true | _ => false) cons
              in
                if nullary andalso withArg then L.RCon
                else if nullary then L.RCon0
                else if withArg then L.RPtr
                else L.RAny
              end
          | NONE =>
              (* a type name of the basis the elaborator made no datatype of:
                 array, vector, ref, and the abstract ones, are in the heap;
                 by stamp, since a parameter's abstract type of that name
                 reaches here *)
              if List.exists (fn c => stamp = #stamp c) [Types.arrayTycon, Types.vectorTycon, Types.refTycon]
              then L.RPtr else L.RAny
  fun setRep (b : builder, x : L.var, r : L.rep) =
    if r = L.RAny then () else
    case IntTable.find (#reps b, x) of
      SOME _ => ()   (* the first word stands: a variable that is another's has the other's *)
    | NONE => IntTable.insert (#reps b, x, r)
  (* its type, where kept: the first word stands, and a variable defAny
     made, which holds each constructor's field of a datatype, has none *)
  fun setTy (b : builder, x : L.var, t : Ty.ty) =
    if not (!keepTys) orelse x < 0 then ()
    else
      let
        val a = !(#tys b)
        val a = if x < Array.length a then a
                else let val a' = Array.array (Int.max (2 * Array.length a, x + 1), NONE)
                     in Array.copy {src = a, dst = a', di = 0}; #tys b := a'; a' end
      in
        case Array.sub (a, x) of
          SOME _ => ()
        | NONE => (case IntTable.find (#reps b, x) of SOME L.RAny => () | _ => Array.update (a, x, SOME t))
      end

  fun newLabel (b : builder) = let val l = !(#nextLabel b) in #nextLabel b := l + 1; l end
  (* a variable of Low: numbered from 0 in each function, so that a target
     keeps what it knows of them in arrays *)
  fun newVar (b : builder) = let val v = !(#nvars b) in #nvars b := v + 1; v end
  fun emit (b : builder, i) = if !(#open' b) then #instrs b := i :: !(#instrs b) else ()
  fun def (b : builder, oper) = let val x = newVar b in emit (b, L.Def (x, oper)); x end
  (* a variable defined by an operation whose representation is known *)
  fun defAs (b : builder, oper, r : L.rep) = let val x = def (b, oper) in setRep (b, x, r); x end
  (* one whose value is of more than one representation, whatever a later
     binding of it says: a datatype's global, in which each constructor
     leaves a field of its own (results) -- an int of one, a string of
     another -- read before the match takes the constructor apart *)
  fun defAny (b : builder, oper) = let val x = def (b, oper) in IntTable.insert (#reps b, x, L.RAny); x end
  fun finish (b : builder, t : L.transfer) =
    if !(#open' b) then
      (#blocks b := {label = !(#label b), params = !(#params b), instrs = List.rev (!(#instrs b)), transfer = t}
                    :: !(#blocks b);
       #open' b := false)
    else ()
  fun start (b : builder, l, params) =
    (if !(#open' b) then bug "a block started before the last was finished" else ();
     #label b := l; #params b := params; #instrs b := []; #open' b := true)

  (* x not made (virt) in the function being made: NONE where it is made, or
     is another function's *)
  fun virtualVar (b : builder, x : int) : virt option =
    case IntTable.find (!virtuals, x) of
      SOME (owner, v) => if owner = #fid b then SOME v else NONE
    | NONE => NONE
  fun virtualOf (b : builder, a : M.atom) : virt option =
    case a of M.Var (x, _) => virtualVar (b, x) | _ => NONE
  fun setVirtual (b : builder, x : int, v : virt) : unit = IntTable.insert (!virtuals, x, (#fid b, v))

  (* Where the value of an expression goes: returned from the function, to a
     block (as its parameter) with the handlers pushed when it was made, or
     to what follows it in the same block. *)
  datatype ret = FunRet | ToBlock of L.label * int | Cont of L.var -> unit

  (* What an expression is lowered in: where its value goes, how many
     handlers the function has pushed, its join points (with the handlers
     pushed where each was made), and the variable of Low each variable of
     Mid bound in the function is. *)
  type cx = {ret : ret, depth : int, labels : (L.label * int) IntMap.map, subst : L.var IntTable.table}

  (* What the REPL's debugger needs of each function (`-g`; the REPL
     roadmap's M12), where debugInfo says so: the variables of Mid bound in
     it, each with the variable of Low it is, and those it captures, each
     with its slot of the closure's environment; by the function's id.
     Kept for the function being lowered in binds, and the functions it is
     in on a stack. *)
  val debugInfo = ref false
  val () = CompilerState.cellRoot ("Lower.debugInfo", debugInfo)
  val debugVars : {id : int, vars : (int * L.var) list, env : (int * int) list} list ref = ref []
  val () = CompilerState.cellRoot ("Lower.debugVars", debugVars)
  (* and, from the register target, the register of each variable of Low
     and the byte of the function's code where it has been set, ~1 for
     none, by the function's id (Regs, whose signature has no room) *)
  val debugRegs : (int * int vector * int vector) list ref = ref []
  val () = CompilerState.cellRoot ("Lower.debugRegs", debugRegs)
  val binds : (int * L.var) list ref = ref []
  val () = CompilerState.cellRoot ("Lower.binds", binds)

  (* x is v from here on: in one table for the function, since each variable
     of Mid is bound once *)
  fun bindAs (cx : cx, x : int, v : L.var) : cx =
    (IntTable.insert (#subst cx, x, v); if !debugInfo then binds := (x, v) :: !binds else (); cx)

  (* An expression with one way out, and that at its end: its value can go
     on in the same block. *)
  fun straight (e : M.exp) : bool =
    case e of
      M.Let (_, _, _, b) => straight b
    | M.Fun (_, b) => straight b
    | M.Mark (_, a) => straight a
    | M.Return _ => true
    | M.Join _ => false
    | M.Jump _ => false
    | M.If _ => false
    | M.Handle _ => false
    | M.Raise _ => false

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
        | M.Jump _ => false
        | M.Raise _ => false
        | M.Return _ => false
    in tail (#body f) end

  (* ---- lowering ---- *)

  fun function (f : M.fundef, pos : Source.span option, group : int) : int =
    let
      val id = !nextFuncId
      val () = nextFuncId := id + 1
      val cs = capturesOf f
      val () = if null (#params f) then bug "a function of no parameter" else ()
      val recursive = group > 1 orelse IntMap.find (!selfRefs, #name f) = SOME true
      val name =
        case #label f of
          SOME n => n
        | NONE => if recursive then "fn" ^ Int.toString (#name f) else "fn"
      val b : builder = {fid = id, blocks = ref [], label = ref 0, params = ref [], instrs = ref [], open' = ref false,
                         nextLabel = ref 0, nvars = ref 0,
                         env = let val t = IntTable.table 16
                               in ignore (List.foldl (fn (x, i) => (IntTable.insert (t, x, i); i + 1)) 0 cs); t end,
                         self = SOME (#name f), span = ref pos, head = ref NONE, reps = IntTable.table 64,
                         tys = ref (Array.array (if !keepTys then 64 else 0, NONE))}
      val () = if !keepTys then IntTable.insert (!lastTys, id, #tys b) else ()
      val ps = List.map (fn (x, t) => let val v = newVar b in setRep (b, v, repOfTy t); setTy (b, v, t); (x, v) end) (#params f)
      val () = start (b, newLabel b, [])
      (* a loop: the entry jumps to the head, whose parameters the body
         reads, and which the calls of the loop jump back to *)
      val bound =
        if loops f then
          let
            val l = newLabel b
            val hs = List.map (fn (x, t) => let val v = newVar b in setRep (b, v, repOfTy t); setTy (b, v, t); (x, v) end) (#params f)
          in
            finish (b, L.Goto (l, List.map #2 ps)); start (b, l, List.map #2 hs); #head b := SOME l; hs
          end
        else ps
      val outer = !binds
      val () = binds := (if !debugInfo then List.rev bound else [])
      val outerSlots = !currentSlots
      val outerSum = !currentSum
      val () = currentSlots := IntMap.find (!slotFuns, #name f)
      val () = currentSum := IntMap.find (!sumFuns, #name f)
      val () = exp (b, #body f, {ret = FunRet, depth = 0, labels = IntMap.empty,
                                 subst = let val t = IntTable.table 64
                                         in List.app (fn (x, v) => IntTable.insert (t, x, v)) bound; t end})
      val () = (currentSlots := outerSlots; currentSum := outerSum)
      (* what it returns: a datatype's tag where it returns the datatype in
         globals, the first field where it returns a tuple so *)
      val result =
        if isSome (IntMap.find (!sumFuns, #name f)) then L.RCon0
        else
          case IntMap.find (!slotFuns, #name f) of
            SOME _ => (case Ty.view (#result f) of Ty.Tuple (t :: _) => repOfTy t | _ => L.RAny)
          | NONE => repOfTy (#result f)
      val () =
        if !debugInfo then
          debugVars := {id = id, vars = !binds, env = #2 (List.foldl (fn (c, (i, acc)) => (i + 1, (c, i) :: acc)) (0, []) cs)}
                       :: !debugVars
        else ()
      val () = binds := outer
    in
      funcs := {id = id, name = name, params = List.map #2 ps, ncaptured = List.length cs, nvars = !(#nvars b),
                blocks = List.rev (!(#blocks b)), pos = pos,
                reps = Vector.tabulate (!(#nvars b), fn x => case IntTable.find (#reps b, x) of SOME r => r | NONE => L.RAny),
                result = result, captures = []}
               :: !funcs;
      id
    end

  (* The variable an atom's value is in, made here where it is a constant,
     a global or a captured value. *)
  and atom (b : builder, cx : cx, a : M.atom) : L.var =
    case a of
      M.Var (x, _) => var (b, cx, x)
    | M.Global (g, _) => def (b, L.Global g)
    | M.Const (c, t) => defAs (b, L.Const c, repOfTy t)
    | M.Con0 (tag, t) => let val v = defAs (b, L.Con0 tag, repOfTy t) in setTy (b, v, t); v end
    | M.Unit => defAs (b, L.Unit, L.RUnit)

  and var (b : builder, cx : cx, x : int) : L.var =
    case IntTable.find (#subst cx, x) of
      SOME y => y
    | NONE =>
        case IntTable.find (#env b, x) of
          SOME i => def (b, L.Env i)
        | NONE =>
            if #self b = SOME x then def (b, L.Self)
            else
              case virtualVar (b, x) of
                SOME (Parts vs) => def (b, L.Tuple vs)
              | SOME (Sum (v, _)) => v
              | SOME (Fields (tag, n, v)) => def (b, L.Tuple (List.tabulate (n, fn i => def (b, L.Field (tag, i, v)))))
              | NONE => bug ("v" ^ Int.toString x ^ " is not in scope")

  and oper (b : builder, cx : cx, r : M.rhs) : L.operation =
    let fun at a = atom (b, cx, a)
    in
      case r of
        M.Atom _ => bug "an atom as an operation"
      | M.App (M.Global (g, _), xs) => if isKnown g then L.CallK (g, List.map at xs) else unknown (b, cx, r)
      | M.App _ => unknown (b, cx, r)
      (* the primitives of the functors' code (docs/ir.md, Functors compiled once), which
         only the compiler makes: a record's slot cast, an application's
         marker, an open constructor's descriptor tested for 0 and worked
         out from its datatype's layout, as it is now *)
      | M.Prim ("functor_cast", _, xs) => L.Prim ("unsafe_cast", List.map at xs)
      | M.Prim ("dynamic_cast", _, xs) => L.Prim ("unsafe_cast", List.map at xs)
      | M.Prim ("open_cast", _, xs) => L.Prim ("unsafe_cast", List.map at xs)
      | M.Prim ("functor_marker", _, xs) => L.Prim ("unsafe_cast", List.map at xs)
      | M.Prim ("open_boxed", _, xs) => L.Prim ("imm_eq", List.map at xs)
      | M.Prim ("open_layout", t, [M.Const (Literal.CInt tag, _)]) => L.Const (Literal.CInt (IntInf.fromInt (openLayout (t, IntInf.toInt tag))))
      | M.Prim (p, _, xs) => L.Prim (p, List.map at xs)
      | M.Tuple xs => L.Tuple (List.map at xs)
      | M.Select (i, a) =>
          (case virtualOf (b, a) of
             SOME (Fields (tag, _, v)) => L.Field (tag, i, v)
           | SOME (Parts vs) => bug "a field of a tuple not made, as an operation"
           | SOME (Sum _) => bug "a field of a constructor returned in globals"
           | NONE => L.Select (i, at a))
      | M.Con (tag, t, a) =>
          (case Rep.fields (t, tag) of
             NONE => L.Con (tag, [at a])
           | SOME n =>
               (* one object of the fields of its argument *)
               (case virtualOf (b, a) of
                  SOME (Parts vs) => L.Con (tag, vs)
                | SOME (Fields (tag', _, v)) => L.Con (tag, List.tabulate (n, fn i => def (b, L.Field (tag', i, v))))
                | SOME (Sum _) => bug "a constructor returned in globals, as an argument"
                | NONE => let val v = at a in L.Con (tag, List.tabulate (n, fn i => def (b, L.Select (i, v)))) end))
      | M.Decon (tag, t, a) =>
          (case Rep.fields (t, tag) of
             NONE => L.Decon (tag, at a)
           | SOME n =>
               (* the argument whole, where a use needs it so: a copy *)
               let val v = at a in L.Tuple (List.tabulate (n, fn i => def (b, L.Field (tag, i, v)))) end)
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

  (* a call of a function that returns in globals: its first field and
     the others, read at once, each of the representation of its type *)
  and slotParts (b, cx, g : int, n : int, xs : M.atom list, ts : Ty.ty list, taken : int list option) : L.var list =
    let
      val v0 = defAs (b, L.CallK (g, List.map (fn a => atom (b, cx, a)) xs), repOfTy (hd ts))
      val () = setTy (b, v0, hd ts)
      fun slot (s, t) = let val v = defAs (b, L.Slot s, repOfTy t) in setTy (b, v, t); v end
      fun read (i, s, t) =
        case taken of
          SOME is => if List.exists (fn j => j = i) is then slot (s, t) else v0
        | NONE => slot (s, t)
    in
      v0 :: ListPair.map (fn ((i, s), t) => read (i, s, t))
                         (ListPair.zip (List.tabulate (n - 1, fn i => i + 1), slotsOf n), tl ts)
    end

  and value (b, cx, r : M.rhs) : L.var =
    case r of
      M.Atom a => atom (b, cx, a)
    | M.App (M.Global (g, _), xs) =>
        (case IntMap.find (!slotFuns, g) of
           SOME n => def (b, L.Tuple (slotParts (b, cx, g, n, xs, List.tabulate (n, fn _ => Ty.var 0), NONE)))
         | NONE => tyOfRhs (b, defAs (b, oper (b, cx, r), repOfRhs r), r))
    | M.Select (i, a) =>
        (case virtualOf (b, a) of
           SOME (Parts vs) => List.nth (vs, i)
         | _ => def (b, oper (b, cx, r)))
    | M.Decon (tag, t, a) =>
        (case virtualOf (b, a) of
           SOME (Sum (_, vs)) =>
             (case Rep.fields (t, tag) of
                NONE => hd vs
              | SOME n => def (b, L.Tuple (List.take (vs, n))))
         | _ => tyOfRhs (b, defAs (b, oper (b, cx, r), repOfRhs r), r))
    | _ => tyOfRhs (b, defAs (b, oper (b, cx, r), repOfRhs r), r)

  (* its type where the operation's own says, as repOfRhs: a primitive's
     result at this use, a constructor's datatype, an exception's argument *)
  and tyOfRhs (b, v : L.var, r : M.rhs) : L.var =
    (case r of
       M.Prim (_, pt, _) => (case Ty.view pt of Ty.Arrow (_, res) => setTy (b, v, res) | _ => ())
     | M.Con (_, t, _) => setTy (b, v, t)
     | M.ExnArg (t, _) => setTy (b, v, t)
     | M.Atom _ => ()
     | M.App _ => ()
     | M.Tuple _ => ()
     | M.Select _ => ()
     | M.Decon _ => ()
     | M.ConTag _ => ()
     | M.NewExn _ => ()
     | M.BuiltinExn _ => ()
     | M.MkExn _ => ()
     | M.ExnCon _ => ()
     | M.SetGlobal _ => ();
     v)

  (* what an operation makes, where its shape says: a primitive's result
     from its type at this use, a tuple, a constructor, an exception in the
     heap, a tag an int; the rest the binder's type says (Let) *)
  and repOfRhs (r : M.rhs) : L.rep =
    case r of
      M.Prim (_, pt, _) => (case Ty.view pt of Ty.Arrow (_, res) => repOfTy res | _ => L.RAny)
    | M.Tuple (_ :: _) => L.RPtr
    | M.Tuple [] => L.RUnit
    | M.Con (_, t, _) => repOfTy t
    | M.ConTag _ => L.RInt
    | M.NewExn _ => L.RPtr
    | M.BuiltinExn _ => L.RPtr
    | M.MkExn _ => L.RPtr
    | M.ExnCon _ => L.RPtr
    | M.ExnArg (t, _) => repOfTy t
    | M.SetGlobal _ => L.RUnit
    | M.Atom _ => L.RAny
    | M.App _ => L.RAny
    | M.Select _ => L.RAny
    | M.Decon _ => L.RAny

  (* x bound to r, where its value need not be made there (virt) *)
  and virtualised (b, cx, x : int, r : M.rhs) : bool =
    case r of
      M.Tuple (xs as _ :: _ :: _) =>
        usesOf x = 1 andalso (setVirtual (b, x, Parts (List.map (fn a => atom (b, cx, a)) xs)); true)
    | M.Decon (tag, t, a) =>
        (case Rep.fields (t, tag) of
           SOME n =>
             usesOf x = selectsOf x
             andalso (setVirtual (b, x, Fields (tag, n, atom (b, cx, a))); true)
         | NONE => false)
    | M.Atom (a as M.Var _) =>
        (* another name for one: the same, where its uses would do *)
        (case virtualOf (b, a) of
           SOME (v as Parts _) => usesOf x = 1 andalso (setVirtual (b, x, v); true)
         | SOME (v as Fields _) => usesOf x = selectsOf x andalso (setVirtual (b, x, v); true)
         | SOME (v as Sum _) => (setVirtual (b, x, v); true)
         | NONE => false)
    | _ => false

  and pops (b, n) = if n <= 0 then () else (emit (b, L.Pop); pops (b, n - 1))

  (* Lower e into the block being filled, which it finishes, but for a Cont,
     whose rest fills it on. *)
  and exp (b : builder, e : M.exp, cx : cx) : unit =
    case e of
      M.Let (x, scheme, r, body) =>
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
             case (r, case r of M.App (M.Global (g, _), _) => IntMap.find (!sumFuns, g) | _ => NONE) of
               (M.App (M.Global (g, _), xs), SOME stamp) =>
                 (* its tag, and what each global holds, read at once *)
                 let
                   val v0 = defAs (b, L.CallK (g, List.map (fn a => atom (b, cx, a)) xs), L.RCon0)
                   val read = case IntTable.find (!sumRead, x) of SOME n => n | NONE => 0
                   val vs = List.tabulate (List.length (sumsOf stamp),
                                           fn i => if i < read then defAny (b, L.Slot (List.nth (sumsOf stamp, i))) else v0)
                 in setVirtual (b, x, Sum (v0, vs)); exp (b, body, cx) end
             | (M.Decon (tag, t, a), _) =>
                 (case virtualOf (b, a) of
                    SOME (Sum (_, vs)) =>
                      (case Rep.fields (t, tag) of
                         NONE => exp (b, body, bindAs (cx, x, hd vs))
                       | SOME n => (setVirtual (b, x, Parts (List.take (vs, n))); exp (b, body, cx)))
                  | _ => letRest (b, cx, x, scheme, r, body))
             | _ => letRest (b, cx, x, scheme, r, body))
    | M.Fun (fs, body) => exp (b, body, closures (b, cx, fs))
    | M.Join (j, ps, jbody, scope) => joinOf (b, cx, j, ps, jbody, scope)
    | M.Jump (j, xs) => jumpOf (b, cx, j, xs)
    | M.If (c, t, f) => ifOf (b, cx, c, t, f)
    | M.Handle (a, x, h) => handleOf (b, cx, a, x, h)
    | M.Raise a => let val v = atom (b, cx, a) in finish (b, L.Raise v) end
    | M.Return r => returnSum (b, cx, r)
    | M.Mark (sp, a) => (emit (b, L.At sp); #span b := SOME (#1 sp); exp (b, a, cx))

  (* a return of a function that returns its datatype in globals: the
     constructor's tag, its argument in the globals *)
  and returnSum (b, cx, r : M.rhs) =
    case (r, !currentSum, #ret cx) of
      (M.Con (tag, t, a), SOME stamp, FunRet) =>
        let
          val parts =
            case Rep.fields (t, tag) of
              NONE => [atom (b, cx, a)]
            | SOME n =>
                (case virtualOf (b, a) of
                   SOME (Parts vs) => vs
                 | SOME (Fields (tag', _, v)) => List.tabulate (n, fn i => def (b, L.Field (tag', i, v)))
                 | _ => let val v = atom (b, cx, a) in List.tabulate (n, fn i => def (b, L.Select (i, v))) end)
          val v0 = defAs (b, L.Con0 tag, L.RCon0)
        in
          ListPair.app (fn (s, v) => ignore (def (b, L.SetGlobal (s, v)))) (sumsOf stamp, parts);
          pops (b, #depth cx); finish (b, L.Return v0)
        end
    | (M.App (M.Global (g, _), xs), SOME stamp, FunRet) =>
        (* a call of one of the same datatype: its globals set by it *)
        if #depth cx = 0 then
          (case !(#head b) of
             SOME l => if #self b = SOME g then finish (b, L.Goto (l, List.map (fn a => atom (b, cx, a)) xs))
                       else knownTail (b, cx, r)
           | NONE => knownTail (b, cx, r))
        else
          let val v = defAs (b, L.CallK (g, List.map (fn a => atom (b, cx, a)) xs), L.RCon0)
          in pops (b, #depth cx); finish (b, L.Return v) end
    | _ => returnTuple (b, cx, r)

  and letRest (b, cx, x, scheme, r, body) =
             case (slotCall r, Ty.view (#2 scheme)) of
               (SOME (g, n, xs), Ty.Tuple ts) =>
                 (case takenOnly x of
                    SOME is => (setVirtual (b, x, Parts (slotParts (b, cx, g, n, xs, ts, SOME is))); exp (b, body, cx))
                  | NONE =>
                      if isSome (IntTable.find (!lazyCalls, x)) then
                        (setVirtual (b, x, Parts (slotParts (b, cx, g, n, xs, ts, NONE))); exp (b, body, cx))
                      else
                      let val vs = slotParts (b, cx, g, n, xs, ts, NONE)
                      in exp (b, body, bindAs (cx, x, defAs (b, L.Tuple vs, L.RPtr))) end)
             | _ =>
             (* a tuple or a constructor nothing uses, which a rewrite of
                Simplify's last round left: not made *)
             if usesOf x = 0 andalso (case r of M.Tuple (_ :: _) => true | M.Con _ => true | _ => false) then exp (b, body, cx)
             else if virtualised (b, cx, x, r) then exp (b, body, cx)
             else
               let val v = value (b, cx, r)
               in setRep (b, v, repOfTy (#2 scheme)); setTy (b, v, #2 scheme); exp (b, body, bindAs (cx, x, v)) end

  and joinOf (b, cx, j, ps, jbody, scope) =
        let val l = newLabel b
        in
          exp (b, scope, {ret = #ret cx, depth = #depth cx, labels = IntMap.insert (#labels cx, j, (l, #depth cx)),
                          subst = #subst cx});
          let val vs = List.map (fn (_, t) => let val v = newVar b in setTy (b, v, t); v end) ps
          in
            start (b, l, vs);
            exp (b, jbody, ListPair.foldl (fn ((x, _), v, cx) => bindAs (cx, x, v)) cx (ps, vs))
          end
        end

  and jumpOf (b, cx, j, xs) =
        (case IntMap.find (#labels cx, j) of
           SOME (l, d) =>
             let val vs = List.map (fn a => atom (b, cx, a)) xs
             in pops (b, #depth cx - d); finish (b, L.Goto (l, vs)) end
         | NONE => bug "a jump to a join point not in scope")

  and ifOf (b, cx, c, t, f) =
        let
          val v = atom (b, cx, c)
          val lt = newLabel b
          val lf = newLabel b
        in
          finish (b, L.If (v, lt, lf));
          start (b, lt, []); exp (b, t, cx);
          start (b, lf, []); exp (b, f, cx)
        end

  and handleOf (b, cx, a, x, h) =
        let val lh = newLabel b
        in
          emit (b, L.Push lh);
          exp (b, a, {ret = #ret cx, depth = #depth cx + 1, labels = #labels cx, subst = #subst cx});
          let val v = newVar b
          in start (b, lh, [v]); exp (b, h, bindAs (cx, x, v)) end
        end

  (* a return of a function that returns its tuple in globals: the first
     field, the others in the globals some call reads *)
  and returnTuple (b, cx, r : M.rhs) =
        (case (#ret cx, r, !currentSlots) of
           (FunRet, M.Tuple (x0 :: rest), SOME n) =>
             let
               val v0 = atom (b, cx, x0)
               val vs = List.map (fn a => atom (b, cx, a)) rest
             in
               ListPair.app (fn ((i, s), v) => if needed (n, i) then ignore (def (b, L.SetGlobal (s, v))) else ())
                            (ListPair.zip (List.tabulate (n - 1, fn i => i + 1), slotsOf n), vs);
               pops (b, #depth cx); finish (b, L.Return v0)
             end
         | (FunRet, M.App (M.Global (g, _), xs), SOME n) =>
             (* a call of one that returns as this one does: its globals are
                this one's, set by it *)
             if #depth cx = 0 then
               (case !(#head b) of
                  SOME l => if #self b = SOME g then finish (b, L.Goto (l, List.map (fn a => atom (b, cx, a)) xs))
                            else knownTail (b, cx, r)
                | NONE => knownTail (b, cx, r))
             else
               let val v = defAs (b, L.CallK (g, List.map (fn a => atom (b, cx, a)) xs), L.RAny)
               in pops (b, #depth cx); finish (b, L.Return v) end
         | (FunRet, M.App (M.Global (g, _), xs), NONE) =>
             (case IntMap.find (!slotFuns, g) of
                SOME _ => let val v = value (b, cx, r) in pops (b, #depth cx); finish (b, L.Return v) end
              | NONE => returnOf (b, cx, r))
         | _ => returnOf (b, cx, r))

  and returnOf (b, cx, r : M.rhs) =
        (case (#ret cx, r) of
           (FunRet, M.App (f, xs)) =>
             (case (#depth cx, !(#head b), f) of
                (0, SOME l, M.Global (g, _)) =>
                  if #self b = SOME g then finish (b, L.Goto (l, List.map (fn a => atom (b, cx, a)) xs))
                  else knownTail (b, cx, r)
              | (0, SOME l, M.Var (x, _)) =>
                  if #self b = SOME x andalso not (isSome (IntTable.find (#subst cx, x))) then
                    finish (b, L.Goto (l, List.map (fn a => atom (b, cx, a)) xs))
                  else knownTail (b, cx, r)
              | _ => knownTail (b, cx, r))
         | (FunRet, _) => let val v = value (b, cx, r) in pops (b, #depth cx); finish (b, L.Return v) end
         | (ToBlock (l, d), _) => let val v = value (b, cx, r) in pops (b, #depth cx - d); finish (b, L.Goto (l, [v])) end
         | (Cont k, _) => k (value (b, cx, r)))

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
              val () = closureSites := IntMap.insert (!closureSites, fid, (#fid b, List.rev vs))
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
      fun fid g =
        case IntMap.find (!globalFids, g) of
          SOME i => i
        | NONE =>
            if !Pass.whole then bug "a known call of no function"
            else
              case IntMap.find (!imported, g) of
                SOME i => i
              | NONE =>
                  let val i = !nextFuncId + IntMap.numItems (!imported)
                  in imported := IntMap.insert (!imported, g, i); i end
      fun instr (L.Def (x, L.CallK (g, vs))) = L.Def (x, L.CallK (fid g, vs))
        | instr i = i
      fun block ({label, params, instrs, transfer} : L.block) : L.block =
        {label = label, params = params, instrs = List.map instr instrs,
         transfer = case transfer of L.TailCallK (g, vs) => L.TailCallK (fid g, vs) | t => t}
      val {id, name, params, ncaptured, nvars, blocks, pos, reps, result, captures} = f
    in
      {id = id, name = name, params = params, ncaptured = ncaptured, nvars = nvars, blocks = List.map block blocks,
       pos = pos, reps = reps, result = result, captures = captures}
    end

  (* What each closure of f captures holds: what the function that makes it
     says of the values it captures there, and a closure of its group made
     after it, in the heap. *)
  fun withCaptures (repsOf : int -> L.rep vector option) (f : L.func) : L.func =
    let
      val {id, name, params, ncaptured, nvars, blocks, pos, reps, result, ...} = f
      val captures =
        case IntMap.find (!closureSites, id) of
          SOME (maker, vs) =>
            (case repsOf maker of
               SOME rs => List.map (fn SOME v => (Vector.sub (rs, v) handle Subscript => L.RAny) | NONE => L.RPtr) vs
             | NONE => List.map (fn _ => L.RAny) vs)
        | NONE => List.tabulate (ncaptured, fn _ => L.RAny)
    in
      {id = id, name = name, params = params, ncaptured = ncaptured, nvars = nvars, blocks = blocks,
       pos = pos, reps = reps, result = result, captures = captures}
    end

  fun program {results : bool} (p : M.program) : L.program =
    let
      val () = resultsOn := (results andalso not (!debugInfo))
      (* the types of the variables, kept where their shapes are checked *)
      val () = (keepTys := !shapesChecked (); lastTys := IntTable.table (if !keepTys then 256 else 1))
      val () = (useCounts := IntTable.table 4096; captures := IntMap.empty; selfRefs := IntMap.empty; funcs := [];
                closureSites := IntMap.empty;
                globalReps :=
                  List.foldl (fn (M.Val (g, (_, t), _), m) => IntMap.insert (m, g, repOfTy t)
                               | (M.Funs fs, m) =>
                                   List.foldl (fn (f, m) => case #params f of
                                                              [_] => IntMap.insert (m, #name f, L.RPtr)
                                                            | _ => m) m fs
                               | (M.Do (gs, _), m) => List.foldl (fn ((g, (_, t)), m) => IntMap.insert (m, g, repOfTy t)) m gs)
                             IntMap.empty p;
                selectUses := IntTable.table 1024; selectFields := IntTable.table 1024; sumUses := IntTable.table 1024; sumRead := IntTable.table 1024; binderFn := IntTable.table 4096; nextFn := 0; virtuals := IntTable.table 1024;
                nextFuncId := 0; globalFids := IntMap.empty; imported := IntMap.empty;
                debugVars := []; binds := [];
                knownFuns := List.foldl (fn (M.Funs fs, m) => List.foldl (fn (f, m) => IntMap.insert (m, #name f, ())) m fs
                                          | (_, m) => m)
                                        (if !Pass.whole then IntMap.empty else !knownBefore) p)
      val () = List.app (fn M.Val (_, _, e) => countExp e
                          | M.Funs fs => List.app (countExp o #body) fs
                          | M.Do (_, e) => countExp e) p
      val () = List.app (fn M.Val (_, _, e) => countSelects e
                          | M.Funs fs => List.app (countSelects o #body) fs
                          | M.Do (_, e) => countSelects e) p
      val () = (slotGlobals := IntMap.empty; currentSlots := NONE; lazyCalls := IntTable.table 64; findSlotFuns p)
      val id = !nextFuncId
      val () = nextFuncId := id + 1
      val b : builder = {fid = id, blocks = ref [], label = ref 0, params = ref [], instrs = ref [], open' = ref false,
                         nextLabel = ref 0, nvars = ref 0, env = IntTable.table 1, self = NONE, span = ref NONE,
                         head = ref NONE, reps = IntTable.table 64, tys = ref (Array.array (if !keepTys then 64 else 0, NONE))}
      val () = if !keepTys then IntTable.insert (!lastTys, id, #tys b) else ()
      val param = newVar b
      val () = start (b, newLabel b, [])
      (* the globals a datatype is returned in, set before any is read *)
      val () =
        case IntMap.listItems (!sumGlobals) of
          [] => ()
        | gss => let val u = defAs (b, L.Unit, L.RUnit)
                 in List.app (fn gs => List.app (fn g => ignore (def (b, L.SetGlobal (g, u)))) gs) gss end
      val topSubst : L.var IntTable.table = IntTable.table 1024
      val top : cx = {ret = FunRet, depth = 0, labels = IntMap.empty, subst = topSubst}
      (* a definition's expression, whose value then goes to k *)
      fun defining (e, k : L.var -> unit) =
        if straight e then exp (b, e, {ret = Cont k, depth = 0, labels = IntMap.empty, subst = topSubst})
        else
          let
            val l = newLabel b
            val x = newVar b
          in
            exp (b, e, {ret = ToBlock (l, 0), depth = 0, labels = IntMap.empty, subst = topSubst});
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
      val () = finish (b, if !Pass.whole then L.Return u else L.TailCallK (nextUnit, [u]))
      val () = ignore top
      val () = if !debugInfo then debugVars := {id = id, vars = !binds, env = []} :: !debugVars else ()
      val topFunc : L.func = {id = id, name = "<toplevel>", params = [param], ncaptured = 0, nvars = !(#nvars b),
                              blocks = List.rev (!(#blocks b)), pos = NONE,
                              reps = Vector.tabulate (!(#nvars b), fn x => case IntTable.find (#reps b, x) of SOME r => r | NONE => L.RAny),
                              result = L.RUnit, captures = []}
      val byId = List.foldl (fn (f : L.func, m) => IntMap.insert (m, #id f, f)) IntMap.empty (topFunc :: !funcs)
      fun repsOf id = Option.map #reps (IntMap.find (byId, id))
    in
      IntMap.listItems (IntMap.map (resolve o withCaptures repsOf) byId)
    end
end
