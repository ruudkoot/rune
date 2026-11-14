(* Workers and wrappers (docs/ir.md; docs/plans/middle-end.md, M8 and D9):
   a function of the top level that takes its arguments in a tuple, or one
   at a time (curried), becomes two. The worker takes them all as its
   parameters and does what the function did; the wrapper, the function as
   it was, takes them as it did and calls the worker, for the uses of the
   function as a value.

   * Flattened: a function with a parameter that is a tuple it only takes
     apart. Every call of it calls the worker with the fields of that
     argument (Select), which the simplifier then finds where the tuple was
     made -- so that it is not made. A field that is a tuple the function
     only takes apart is flattened too, and so on (performance M8: a
     function of two vectors of three reals takes six reals); a variable
     bound to the parameter, or to such a field, is the same.
   * Curried: a function whose body only makes a function and returns it,
     and so on, n deep, of which the innermost's body is the worker's. A
     call of it that is given every level's arguments -- each partial application
     used once, by the application to the next argument, further down the
     same straight line -- calls the worker; the partial applications only
     made closures, so none is made.

   A worker has the function's type variables and name (for traces); only
   known calls call it (Lower's CallK), and it is made no closure. A wrapper
   nothing names once every call is the worker's goes. *)
structure Workers =
struct
  open Mid

  val freshStamp = Stamp.fresh

  (* Whether x is used in e only as the tuple of a Select. *)
  fun onlySelected (x : var, e : exp) : bool =
    let
      fun ok a = case a of Var (y, _) => y <> x | _ => true
      fun oks xs = List.all ok xs
      fun rhs r =
        case r of
          Select _ => true
        | _ => allAtomsOfRhs ok r
      fun exp e =
        case e of
          Let (_, _, r, b) => rhs r andalso exp b
        | Fun (fs, b) => List.all (fn f => exp (#body f)) fs andalso exp b
        | Join (_, _, body, s) => exp body andalso exp s
        | Jump (_, xs) => oks xs
        | If (c, t, f) => ok c andalso exp t andalso exp f
        | Handle (a, _, h) => exp a andalso exp h
        | Raise a => ok a
        | Return r => rhs r
        | Mark (_, a) => exp a
        | Case (a, arms, d) => ok a andalso List.all exp (caseExps (arms, d))
    in exp e end

  (* How a flattened parameter's fields are passed: each one as it is, or,
     where it is a tuple that is only taken apart, its own fields. *)
  datatype field = Leaf of Ty.ty | Nest of field list

  fun leaves (fs : field list) : Ty.ty list =
    List.concat (List.map (fn Leaf t => [t] | Nest fs => leaves fs) fs)

  (* The variables of e bound to x itself (Atom) or to a field of it
     (Select), x's names and fields, and whether x and its names have no
     other use. *)
  fun fieldsOf (x : var, e : exp) : (int * var * Ty.ty) list option =
    let
      val names = ref [x]
      val fields = ref []
      fun isName y = List.exists (fn n => n = y) (!names)
      fun ok a = case a of Var (y, _) => not (isName y) | _ => true
      fun oks xs = List.all ok xs
      fun rhs (v, t) r =
        case r of
          Atom (Var (y, [])) => if isName y then (names := v :: !names; true) else true
        | Select (i, Var (y, _)) => (if isName y then fields := (i, v, t) :: !fields else (); true)
        | _ => allAtomsOfRhs ok r
      (* a field returned is taken whole: ~1 for its variable *)
      fun ret r =
        case r of
          Select (i, Var (y, _)) => (if isName y then fields := (i, ~1, Ty.unit) :: !fields else (); true)
        | Select _ => true
        | Atom a => ok a
        | _ => rhs (0, Ty.unit) r
      fun exp e =
        case e of
          Let (v, (_, t), r, b) => rhs (v, t) r andalso exp b
        | Fun (fs, b) => List.all (fn f => exp (#body f)) fs andalso exp b
        | Join (_, _, body, s) => exp body andalso exp s
        | Jump (_, xs) => oks xs
        | If (c, t, f) => ok c andalso exp t andalso exp f
        | Handle (a, _, h) => exp a andalso exp h
        | Raise a => ok a
        | Return r => ret r
        | Mark (_, a) => exp a
        | Case (a, arms, d) => ok a andalso List.all exp (caseExps (arms, d))
    in
      if exp e then SOME (List.rev (!fields)) else NONE
    end

  (* The fields of a tuple x of types ts that e only takes apart: a field
     that is itself such a tuple, wherever it is taken, is nested; NONE
     where x has another use. *)
  fun flatFields (x : var, ts : Ty.ty list, e : exp) : field list option =
    case fieldsOf (x, e) of
      NONE => NONE
    | SOME taken =>
        SOME (List.tabulate (List.length ts, fn i =>
                case (Ty.view (List.nth (ts, i)), List.filter (fn (j, _, _) => j = i) taken) of
                  (Ty.Tuple (us as _ :: _ :: _), vs as _ :: _) =>
                    let
                      val nested = List.map (fn (_, v, _) => if v < 0 then NONE else flatFields (v, us, e)) vs
                    in
                      if List.all isSome nested then
                        (* nested as deep as every place it is taken asks *)
                        Nest (List.foldl (fn (SOME fs, acc) => meet (fs, acc) | (NONE, acc) => acc)
                                         (valOf (hd nested)) (tl nested))
                      else Leaf (List.nth (ts, i))
                    end
                | _ => Leaf (List.nth (ts, i))))

  and meet (a : field list, b : field list) : field list =
    ListPair.map (fn (Nest x, Nest y) => Nest (meet (x, y))
                   | (Leaf t, _) => Leaf t
                   | (Nest x, Leaf t) => Leaf t) (a, b)

  (* How often each variable is used in e, added to the table. *)
  fun count (uses : int IntTable.table) (e : exp) : unit =
    let
      fun atom a =
        case a of
          Var (x, _) => IntTable.bump (uses, x)
        | _ => ()
      fun rhs r = appAtomsOfRhs atom r
      fun exp e =
        case e of
          Let (_, _, r, b) => (rhs r; exp b)
        | Fun (fs, b) => (List.app (fn f => exp (#body f)) fs; exp b)
        | Join (_, _, body, s) => (exp body; exp s)
        | Jump (_, xs) => List.app atom xs
        | If (c, t, f) => (atom c; exp t; exp f)
        | Handle (a, _, h) => (exp a; exp h)
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => exp a
        | Case (a, arms, d) => (atom a; List.app exp (caseExps (arms, d)))
    in exp e end

  fun unmark (Mark (_, e)) = unmark e
    | unmark e = e

  (* The levels of a curried function: each one's parameters -- the
     function's own, then one for each function inside -- and the type of
     what it returns, and the body of the innermost. A level's function
     abstracts over no type variables and names itself nowhere. *)
  fun levels (f : fundef) : ((var * Ty.ty) list * Ty.ty * string option) list * exp =
    let
      fun mentions (x, e) =
        let val t = IntTable.table 16
        in count t e; isSome (IntTable.find (t, x)) end
      fun go (acc, e) =
        case unmark e of
          Fun ([{name, label, tyvars = [], params = [p], result, body}], Return (Atom (Var (n, [])))) =>
            if n = name andalso not (mentions (name, body)) then go (([p], result, label) :: acc, body)
            else (List.rev acc, e)
        | _ => (List.rev acc, e)
    in
      go ([(#params f, #result f, #label f)], #body f)
    end

  datatype shape =
      Flat of field list option list      (* for each parameter, its fields where it is flattened *)
    | Curried of ((var * Ty.ty) list * Ty.ty * string option) list * exp  (* the levels, and the innermost body *)

  type worker = {worker : var, tyvars : int list, shape : shape}

  fun program (target : Target.t) (p : program) : program =
    let
      (* the functions that get a worker, by name; each is one rewrite *)
      fun fits n = n <= #maxArgs target
      fun candidate (f as {name, tyvars, params, body, ...} : fundef, m) =
        case levels f of
          (ls as _ :: _ :: _, inner) =>
            if fits (List.foldl (fn ((ps, _, _), n) => n + List.length ps) 0 ls) andalso Pass.spend () then
              IntMap.insert (m, name, {worker = freshStamp (), tyvars = tyvars, shape = Curried (ls, inner)})
            else m
        | _ =>
            let
              (* a tuple with a polymorphic field stays one: a parameter's
                 type is no forall (Mid.fundef, Ty.Forall) *)
              val specs =
                List.map (fn (x, t) => case Ty.view t of
                                         Ty.Tuple ts => if List.length ts >= 2 andalso not (Ty.hasForall t) then flatFields (x, ts, body)
                                                        else NONE
                                       | _ => NONE) params
              val arity = List.foldl (fn (SOME fs, n) => n + List.length (leaves fs) | (NONE, n) => n + 1) 0 specs
            in
              if List.exists isSome specs andalso fits arity andalso Pass.spend () then
                IntMap.insert (m, name, {worker = freshStamp (), tyvars = tyvars, shape = Flat specs})
              else m
            end
      val workers : worker IntMap.map =
        List.foldl (fn (Funs fs, m) => List.foldl candidate m fs | (_, m) => m) IntMap.empty p

      (* How often each function with a worker is named, and each call of it
         that goes to the worker: a wrapper named no more than that goes.
         A definition that names none, and defines none, is left as it is. *)
      val refs : int IntTable.table = IntTable.table 1024
      val redirected : int IntTable.table = IntTable.table 1024
      fun bump (t, x) = IntTable.bump (t, x)
      fun refsIn (e : exp) : bool =
        let
          val any = ref false
          fun atom a =
            case a of
              Global (g, _) => if IntMap.member (workers, g) then (bump (refs, g); any := true) else ()
            | _ => ()
          fun exp e =
            case e of
              Let (_, _, r, b) => (rhs r; exp b)
            | Fun (fs, b) => (List.app (fn f => exp (#body f)) fs; exp b)
            | Join (_, _, body, s) => (exp body; exp s)
            | Jump (_, xs) => List.app atom xs
            | If (c, t, f) => (atom c; exp t; exp f)
            | Handle (a, _, h) => (exp a; exp h)
            | Raise a => atom a
            | Return r => rhs r
            | Mark (_, a) => exp a
            | Case (a, arms, d) => (atom a; List.app exp (caseExps (arms, d)))
          and rhs r = appAtomsOfRhs atom r
        in exp e; !any end
      val touched =
        List.map (fn d as Val (_, _, e) => (d, refsIn e)
                   | d as Funs fs =>
                       (d, List.foldl (fn (f, any) => refsIn (#body f) orelse any) false fs
                           orelse List.exists (fn f => IntMap.member (workers, #name f)) fs)
                   | d as Do (_, e) => (d, refsIn e)) p

      (* how often each variable is used, for the partial applications *)
      val uses : int IntTable.table = IntTable.table 4096
      val () = List.app (fn (Val (_, _, e), true) => count uses e
                          | (Funs fs, true) => List.app (fn f => count uses (#body f)) fs
                          | (Do (_, e), true) => count uses e
                          | _ => ()) touched
      fun usedOnce x = IntTable.find (uses, x) = SOME 1

      (* The arguments of a worker, from those of the function: each kept,
         or the fields of one flattened, each in a variable -- and a nested
         one's fields in turn -- in reverse; and the steps that take them,
         to put before the call. *)
      fun takeApart (s, argSpecs : (atom * field list option) list) : atom list * (exp -> exp) =
        let
          fun fields (a, fs, (args, lets)) =
            #2 (List.foldl
                  (fn (f, (i, (args, lets))) =>
                     let
                       val t = Ty.subst s (case f of Leaf t => t | Nest fs => Ty.tuple (leavesTy fs))
                       val x = freshStamp ()
                       val lets' = fn e => lets (Let (x, ([], t), Select (i, a), e))
                     in
                       case f of
                         Leaf _ => (i + 1, (Var (x, []) :: args, lets'))
                       | Nest fs => (i + 1, fields (Var (x, []), fs, (args, lets')))
                     end)
                  (0, (args, lets)) fs)
          fun each ((a, NONE), (args, lets)) = (a :: args, lets)
            | each ((a, SOME fs), acc) = fields (a, fs, acc)
        in
          List.foldl each ([], fn e => e) argSpecs
        end
      (* A nested field's type, back from its fields. *)
      and leavesTy (fs : field list) : Ty.ty list =
        List.map (fn Leaf t => t | Nest fs => Ty.tuple (leavesTy fs)) fs

      (* A call of a flattened function: the fields of each argument it
         flattens, each in a variable, and the worker's call in k. *)
      fun flat ({worker, tyvars, ...} : worker, specs, ts, args, k : rhs -> exp) : exp =
        let
          val s = ListPair.foldl (fn (v, t, s) => IntMap.insert (s, v, t)) IntMap.empty (tyvars, ts)
          val (args', lets) = takeApart (s, ListPair.zip (args, specs))
        in
          lets (k (App (Global (worker, ts), List.rev args')))
        end

      (* The one use of h along the straight line e: a call of it, with its
         argument; what comes before it, to put back; and where its value
         goes -- a variable, its scheme and what follows, or the return. *)
      fun spine (h : var, e : exp) : (atom * (exp -> exp) * (var * scheme * exp) option) option =
        case e of
          Let (x, s, r as App (Var (h', _), [y]), rest) =>
            if h' = h then SOME (y, fn e => e, SOME (x, s, rest))
            else Option.map (fn (y, pre, found) => (y, fn e => Let (x, s, r, pre e), found)) (spine (h, rest))
        | Let (x, s, r, rest) => Option.map (fn (y, pre, found) => (y, fn e => Let (x, s, r, pre e), found)) (spine (h, rest))
        | Mark (sp, a) => Option.map (fn (y, pre, found) => (y, fn e => Mark (sp, pre e), found)) (spine (h, a))
        | Return (App (Var (h', _), [y])) => if h' = h then SOME (y, fn e => e, NONE) else NONE
        | _ => NONE

      (* A curried call: h holds the function applied to args, with more
         applications to come; each one's argument, found down e, and the
         worker's call of all of them where the last application was. *)
      fun curried (worker : var, more, ts, h, args, e) : exp option =
        case spine (h, e) of
          NONE => NONE
        | SOME (y, pre, found) =>
            let
              val args = args @ [y]
              val call = App (Global (worker, ts), args)
            in
              if more = 1 then
                SOME (pre (case found of SOME (x, s, rest) => Let (x, s, call, rest) | NONE => Return call))
              else
                case found of
                  SOME (x, _, rest) =>
                    if usedOnce x then Option.map pre (curried (worker, more - 1, ts, x, args, rest)) else NONE
                | NONE => NONE
            end

      fun exp e =
        case e of
          Let (x, s, r as App (Global (f, ts), args), b) =>
            (case IntMap.find (workers, f) of
               SOME (w as {shape = Flat specs, ...}) =>
                 if List.length specs = List.length args then
                   (bump (redirected, f); flat (w, specs, ts, args, fn r' => Let (x, s, r', exp b)))
                 else Let (x, s, r, exp b)
             | SOME {worker, shape = Curried (ls, _), ...} =>
                 (case if usedOnce x then curried (worker, List.length ls - 1, ts, x, args, b) else NONE of
                    SOME e' => (bump (redirected, f); exp e')
                  | NONE => Let (x, s, r, exp b))
             | NONE => Let (x, s, r, exp b))
        | Let (x, s, r, b) => Let (x, s, r, exp b)
        | Fun (fs, b) => Fun (List.map fundef fs, exp b)
        | Join (j, ps, body, sc) => Join (j, ps, exp body, exp sc)
        | If (c, t, f) => If (c, exp t, exp f)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Return (r as App (Global (f, ts), args)) =>
            (case IntMap.find (workers, f) of
               SOME (w as {shape = Flat specs, ...}) =>
                 if List.length specs = List.length args then (bump (redirected, f); flat (w, specs, ts, args, Return))
                 else Return r
             | _ => Return r)
        | Mark (sp, a) => Mark (sp, exp a)
        | Case (a, arms, d) => let val (arms, d) = mapCase exp (arms, d) in Case (a, arms, d) end
        | Jump _ => e
        | Raise _ => e
        | Return _ => e
      and fundef ({name, label, tyvars, params, result, body} : fundef) : fundef =
        {name = name, label = label, tyvars = tyvars, params = params, result = result, body = exp body}

      fun renamed (_ : var) : var = freshStamp ()

      (* A function with a worker: the worker and the wrapper. *)
      fun split (f as {name, label, tyvars, params, result, body} : fundef) : fundef list =
        case IntMap.find (workers, name) of
          SOME {worker, shape = Flat specs, ...} =>
            let
              (* the worker's parameters: one kept as it is, and the fields
                 of one flattened where the function took it apart *)
              val ps = ListPair.zip (params, specs)
              (* each flattened parameter, and each variable that is it or a
                 nested field of it: the worker's parameters it is made of *)
              datatype part = PLeaf of var | PNest of part list
              val parts : part IntTable.table = IntTable.table 16
              fun partsOf (x, fs) = PNest (List.map (fn Leaf _ => PLeaf (renamed x) | Nest fs => partsOf (x, fs)) fs)
              val () = List.app (fn ((x, _), SOME fs) => IntTable.insert (parts, x, partsOf (x, fs)) | _ => ()) ps
              fun partLeaves (PLeaf v) = [v]
                | partLeaves (PNest ps) = List.concat (List.map partLeaves ps)
              fun sel e =
                case e of
                  Let (v, s, r as Select (i, Var (x', _)), b) =>
                    (case IntTable.find (parts, x') of
                       SOME (PNest ps) =>
                         (case List.nth (ps, i) of
                            PLeaf y => Let (v, s, Atom (Var (y, [])), sel b)
                          | p => (IntTable.insert (parts, v, p); sel b))
                     | _ => Let (v, s, r, sel b))
                | Let (v, s, r as Atom (Var (x', [])), b) =>
                    (case IntTable.find (parts, x') of
                       SOME p => (IntTable.insert (parts, v, p); sel b)
                     | NONE => Let (v, s, r, sel b))
                | Let (v, s, r, b) => Let (v, s, r, sel b)
                | Fun (fs, b) =>
                    Fun (List.map (fn {name, label, tyvars, params, result, body} =>
                                     {name = name, label = label, tyvars = tyvars, params = params, result = result, body = sel body}) fs,
                         sel b)
                | Join (j, ps, jb, sc) => Join (j, ps, sel jb, sel sc)
                | If (c, t, e) => If (c, sel t, sel e)
                | Handle (a, v, h) => Handle (sel a, v, sel h)
                | Return (Select (i, Var (x', _))) =>
                    (case IntTable.find (parts, x') of
                       SOME (PNest ps) => (case List.nth (ps, i) of PLeaf y => Return (Atom (Var (y, []))) | _ => e)
                     | _ => e)
                | Mark (sp, a) => Mark (sp, sel a)
                | Case (a, arms, d) => let val (arms, d) = mapCase sel (arms, d) in Case (a, arms, d) end
                | Jump _ => e
                | Raise _ => e
                | Return _ => e
              val workerParams =
                List.concat (List.map (fn ((x, t), NONE) => [(x, t)]
                                        | ((x, _), SOME fs) => ListPair.zip (partLeaves (valOf (IntTable.find (parts, x))), leaves fs))
                                      ps)
              val workerDef = {name = worker, label = label, tyvars = tyvars, params = workerParams, result = result, body = sel (exp body)}
              (* the wrapper: a kept parameter renamed and passed on, a
                 flattened one taken apart *)
              val wrapperParams = List.map (fn ((x, t), NONE) => (renamed x, t) | ((x, t), SOME _) => (x, t)) ps
              val (args, lets) =
                takeApart (IntMap.empty, ListPair.map (fn ((x, _), spec) => (Var (x, []), spec)) (wrapperParams, specs))
              val call = App (Global (worker, List.map Ty.gen tyvars), List.rev args)
            in
              [workerDef, {name = name, label = label, tyvars = tyvars, params = wrapperParams, result = result, body = lets (Return call)}]
            end
        | SOME {worker, shape = Curried (ls, inner), ...} =>
            let
              (* the worker has every level's parameters and the innermost
                 body; the wrapper takes them level by level again, in
                 closures of its own *)
              val workerDef = {name = worker, label = label, tyvars = tyvars, params = List.concat (List.map #1 ls),
                               result = #2 (List.last ls), body = exp inner}
              val ls' = List.map (fn (ps, r, l) => (List.map (fn (x, t) => (renamed x, t)) ps, r, l)) ls
              val call = App (Global (worker, List.map Ty.gen tyvars),
                              List.map (fn (x, _) => Var (x, [])) (List.concat (List.map #1 ls')))
              fun level [] = Return call
                | level ((ps, r, l) :: rest) =
                    let val g = freshStamp ()
                    in Fun ([{name = g, label = l, tyvars = [], params = ps, result = r, body = level rest}], Return (Atom (Var (g, [])))) end
            in
              [workerDef, {name = name, label = label, tyvars = tyvars, params = #1 (hd ls'), result = #2 (hd ls'), body = level (tl ls')}]
            end
        | NONE => [fundef f]
    in
      if IntMap.isEmpty workers then p
      else
        let
          val p' = List.map (fn (d, false) => d
                              | (Val (g, s, e), true) => Val (g, s, exp e)
                              | (Funs fs, true) => Funs (List.concat (List.map split fs))
                              | (Do (gs, e), true) => Do (gs, exp e)) touched
          (* a wrapper nothing names now, every call being the worker's, goes;
             in a unit, a unit after it may name it (Pass.whole) *)
          fun times (t, x) = case IntTable.find (t, x) of SOME n => n | NONE => 0
          fun wanted (f : fundef) =
            not (!Pass.whole) orelse not (IntMap.member (workers, #name f))
            orelse times (refs, #name f) > times (redirected, #name f)
        in
          List.mapPartial (fn Funs fs => (case List.filter wanted fs of [] => NONE | fs' => SOME (Funs fs'))
                            | d => SOME d) p'
        end
    end
end

(* Uncurrying, for eval/apply proper (the haskell98 roadmap's D15 C;
   decided 2026-11-13): what makes SML's curried functions reach the calls
   of n arguments that test the closure's arity, the register set's CALLN
   and the stack set's (src/isa/regs.sml, src/isa/stack.sml), from -O1.

   * A curried function -- one whose body makes a function and returns
     it, n deep (Workers.levels), with nothing between but steps that may
     be done later and again (levels below) -- gets an n-ary twin, of
     every level's parameter and the innermost body after those steps (for
     a global one Workers gave a worker, the worker itself), and its uses
     as a value become the twin's: a closure of n parameters, which a call
     of n arguments enters at once. Each function's twin is made before
     those of the functions inside it.
   * A call through a closure whose result, used once, is applied at once
     to another argument, and so on, becomes one call of them all
     (App (f, [a1, .., an]), Lower's CallN): of a local curried function,
     its twin's where the arguments are as many as its parameters. A step
     between the calls that makes or takes apart a value, of what the
     calls do not give, goes before the first.
   * A local function every use of which became its twin's goes.
   A closure given to thunk_make, to a foreign callback or to the
   runtime (rt_) stays as it is: each enters a closure of one parameter. *)
structure Uncurry =
struct
  open Mid

  (* the most parameters a twin has, and the most arguments a call of
     them all is given *)
  val maxArity = 8

  val freshStamp = Stamp.fresh

  (* The levels of a curried function, as Workers.levels gives them, and
     on past steps between a level and the function of the next that may
     be done later, and again, with nothing seen: a value named, made or
     taken apart, or cast (unsafe_cast), a suspension forced (thunk_force:
     the same value each time, its work done once; a suspension made is not
     one, whose work a partial application applied twice would do twice),
     of no global (a global's value may come later than the step). The innermost body has
     those steps before it, in order: the twin does them once it has every
     argument. *)
  datatype step = Step of var * scheme * rhs | At of pos
  fun ofNoGlobal r = let val g = ref false in appAtomsOfRhs (fn Global _ => g := true | _ => ()) r; not (!g) end
  fun later r =
    (case r of
       Atom _ => true | Tuple _ => true | Select _ => true | Con _ => true | Decon _ => true
     | Prim ("thunk_force", _, _) => true | Prim ("unsafe_cast", _, _) => true
     | _ => false)
    andalso ofNoGlobal r
  (* mentions (x, e): whether the body e of the function x names x *)
  fun levels (mentions : var * exp -> bool) (f : fundef) : ((var * Ty.ty) list * Ty.ty * string option) list * exp =
    let
      fun wrap (steps, e) = List.foldr (fn (Step (x, s, r), e) => Let (x, s, r, e) | (At sp, e) => Mark (sp, e)) e steps
      (* acc the levels, the last first; done the steps after the levels
         before the last, start the body of the last; pending the steps
         passed since (the last first), e where they end *)
      fun go (acc, done, start, pending, e) =
        case e of
          Mark (sp, e') => go (acc, done, start, At sp :: pending, e')
        | Let (x, s, r, e') => if later r then go (acc, done, start, Step (x, s, r) :: pending, e') else stop (acc, done, start)
        | Fun ([{name, label, tyvars = [], params = [p], result, body}], scope) =>
            (case Workers.unmark scope of
               Return (Atom (Var (n, []))) =>
                 if n = name andalso not (mentions (name, body))
                 then go (([p], result, label) :: acc, done @ List.rev pending, body, [], body)
                 else stop (acc, done, start)
             | _ => stop (acc, done, start))
        | _ => stop (acc, done, start)
      and stop (acc, done, start) = (List.rev acc, wrap (done, start))
    in
      go ([(#params f, #result f, #label f)], [], #body f, [], #body f)
    end

  (* a step that rewrite's chain may move before a call (its early), by its
     shape alone *)
  fun earlyShape r =
    case r of
      Atom _ => true | Tuple _ => true | Select _ => true | Con _ => true | Decon _ => true
    | Prim ("unsafe_cast", _, _) => true | Prim ("thunk_make", _, _) => true
    | _ => false
  (* whether a call of x may come next in e, past the steps and functions a
     chain passes (rewrite's chain, go): the variables bound to a call's
     result whose uses it asks of are among those *)
  fun appliedNext (x, e) =
    case e of
      Mark (_, e) => appliedNext (x, e)
    | Let (_, _, App (Var (y, _), _), _) => y = x
    | Return (App (Var (y, _), _)) => y = x
    | Let (_, _, r, e) => earlyShape r andalso appliedNext (x, e)
    | Fun (_, e) => appliedNext (x, e)
    | _ => false

  (* how many times each variable Uncurry asks of is named, as an atom, in
     e, added to t: a local function's name (levels, keep), and one bound to
     a call's result that a call may apply next (chain's usedOnce) -- each
     made a key where it is bound, before any use of it, and its uses
     counted; no other variable is a key *)
  fun countIn (t : int IntTable.table) (e : exp) : unit =
    let
      fun atom a = case a of Var (x, _) => if isSome (IntTable.find (t, x)) then IntTable.bump (t, x) else () | _ => ()
      fun exp e =
        case e of
          Let (x, _, r, b) =>
            ((case r of App _ => if appliedNext (x, b) then IntTable.insert (t, x, 0) else () | _ => ());
             appAtomsOfRhs atom r; exp b)
        | Fun (fs, b) => (List.app (fn f => IntTable.insert (t, #name f, 0)) fs; List.app (fn f => exp (#body f)) fs; exp b)
        | Join (_, _, body, s) => (exp body; exp s)
        | Jump (_, xs) => List.app atom xs
        | If (c, a, b) => (atom c; exp a; exp b)
        | Handle (a, _, h) => (exp a; exp h)
        | Raise a => atom a
        | Return r => appAtomsOfRhs atom r
        | Mark (_, a) => exp a
        | Case (a, arms, d) => (atom a; List.app exp (caseExps (arms, d)))
    in exp e end
  (* in the program *)
  fun countUses (p : program) : int IntTable.table =
    let val t : int IntTable.table = IntTable.table 4096
    in
      List.app (fn Val (_, _, e) => countIn t e | Funs fs => List.app (fn f => countIn t (#body f)) fs | Do (_, e) => countIn t e) p;
      t
    end

  fun program (p : program) : program =
    let
      (* the uses of the variables asked of (countIn), counted once: in the
         program given, and in each twin once it is made (what rewrite
         asks); a level's function in the program given names itself in its
         body where it is named more than once, since it is named once at
         the end of its scope (levels), and one of a twin's own is asked of
         its body *)
      val uses = countUses p
      fun mentions (x, e) =
        case IntTable.find (uses, x) of
          SOME n => n > 1
        | NONE => let val t = IntTable.table 16 in Workers.count t e; isSome (IntTable.find (t, x)) end
      (* the twins, by the curried function's name: the twin's, its arity,
         and whether it is a global (a worker Workers gave a global
         function, which a local one may call: the twin of both) *)
      val twins : (var * int * bool) IntTable.table = IntTable.table 64
      (* the global functions, by name, and the local ones *)
      val globalFuns : fundef IntTable.table = IntTable.table 256
      val () = List.app (fn Funs fs => List.app (fn f => IntTable.insert (globalFuns, #name f, f)) fs | _ => ()) p
      val localFuns : unit IntTable.table = IntTable.table 256
      (* whether twinsIn is in a twin's body; the twins made outside any,
         each group's *)
      val inTwin = ref false
      val made : fundef list list ref = ref []

      (* the twin of f, where f is curried: an existing worker, or a new
         function made of its innermost body *)
      fun twinOf (f : fundef) : fundef option option =
        case levels mentions f of
          (ls as _ :: _ :: _, inner) =>
            if List.length ls > maxArity orelse not (List.all (fn (ps, _, _) => List.length ps = 1) ls) then NONE
            else
              let
                val ps = List.concat (List.map #1 ls)
                val n = List.length ps
                val worker =
                  case Workers.unmark inner of
                    Return (App (Global (w, ts), args)) =>
                      (case IntTable.find (globalFuns, w) of
                         SOME wf =>
                           if List.length (#params wf) = n andalso #tyvars wf = #tyvars f
                              andalso ListPair.allEq (fn (Var (x, []), (y, _)) => x = y | _ => false) (args, ps)
                              andalso ListPair.allEq (fn (t, a) => Ty.equal (t, Ty.gen a)) (ts, #tyvars f)
                           then SOME w else NONE
                       | NONE => NONE)
                  | _ => NONE
              in
                case worker of
                  SOME w => (IntTable.insert (twins, #name f, (w, n, true)); SOME NONE)
                | NONE =>
                    let
                      val ps' = List.map (fn (x, t) => (freshStamp (), t)) ps
                      val s = ListPair.foldl (fn ((x, _), (y, _), m) => IntMap.insert (m, x, y)) IntMap.empty (ps, ps')
                      val name = freshStamp ()
                      val twin = {name = name, label = #label f, tyvars = #tyvars f, params = ps', result = #2 (List.last ls),
                                  body = Simplify.copyWith (s, inner)}
                    in
                      IntTable.insert (twins, #name f, (name, n, isSome (IntTable.find (globalFuns, #name f))));
                      SOME (SOME twin)
                    end
              end
        | _ => NONE

      (* a group with its twins after it: each function's made of it as it
         is, before the functions inside it get theirs (beside a level's
         function, its twin would end the levels there); then each given
         the twins inside it *)
      fun group (fs : fundef list) : fundef list =
        let
          val ts = List.mapPartial (fn f => case twinOf f of SOME (SOME t) => SOME t | _ => NONE) fs
          val fs' = List.map (fn f => withBody (f, twinsIn (#body f))) fs
          (* a twin's body, with the twins inside it, is counted once, as
             it is when made: a twin made inside one is counted with it *)
          val outer = not (!inTwin)
          val () = inTwin := true
          val ts' = List.map (fn f => withBody (f, twinsIn (#body f))) ts
          val () = inTwin := not outer
          val () = if outer then made := ts' :: !made else ()
        in fs' @ ts' end

      (* the program with every curried function's twin beside it *)
      and twinsIn e =
        case e of
          Let (x, s, r, b) => Let (x, s, r, twinsIn b)
        | Fun (fs, b) =>
            let
              val () = List.app (fn f => IntTable.insert (localFuns, #name f, ())) fs
              val fs' = group fs
            in List.app (fn f => IntTable.insert (localFuns, #name f, ())) fs'; Fun (fs', twinsIn b) end
        | Join (j, ps, body, s) => Join (j, ps, twinsIn body, twinsIn s)
        | If (c, a, b) => If (c, twinsIn a, twinsIn b)
        | Handle (a, x, h) => Handle (twinsIn a, x, twinsIn h)
        | Mark (sp, a) => Mark (sp, twinsIn a)
        | Case (a, arms, d) => let val (arms, d) = mapCase twinsIn (arms, d) in Case (a, arms, d) end
        | Jump _ => e
        | Raise _ => e
        | Return _ => e
      and withBody ({name, label, tyvars, params, result, ...} : fundef, body) : fundef =
        {name = name, label = label, tyvars = tyvars, params = params, result = result, body = body}
      val p =
        List.map (fn Val (g, s, e) => Val (g, s, twinsIn e)
                   | Funs fs => Funs (group fs)
                   | Do (gs, e) => Do (gs, twinsIn e)) p
      val () = List.app (fn Funs fs => List.app (fn f => IntTable.insert (globalFuns, #name f, f)) fs | _ => ()) p
      (* the uses of the program as it is now: the twins' too *)
      val () = List.app (List.app (fn f => countIn uses (#body f))) (!made)
    in
      rewrite (p, twins, globalFuns, localFuns, uses)
    end

  (* the uses as values become the twins', and calls in a row one call;
     uses the uses of each variable and global in p *)
  and rewrite (p : program, twins, globalFuns, localFuns, uses) : program =
    let
      val valGlobals : unit IntTable.table = IntTable.table 256
      val () = List.app (fn Val (g, _, _) => IntTable.insert (valGlobals, g, ())
                          | Do (gs, _) => List.app (fn (g, _) => IntTable.insert (valGlobals, g, ())) gs
                          | Funs _ => ()) p
      (* the uses of each local function that became its twin's: one
         named no more, every use of it its twin's, goes (keep) *)
      val replaced : int IntTable.table = IntTable.table 64
      fun usedOnce x = case IntTable.find (uses, x) of SOME 1 => true | _ => false
      fun twinNamed (x2, ts, global) = if global then Global (x2, ts) else Var (x2, ts)
      fun twinAtom a =
        case a of
          Global (g, ts) => (case IntTable.find (twins, g) of SOME (g2, _, _) => Global (g2, ts) | NONE => a)
        | Var (x, ts) =>
            (case IntTable.find (twins, x) of
               SOME (x2, _, global) => (IntTable.bump (replaced, x); twinNamed (x2, ts, global))
             | NONE => a)
        | _ => a
      fun rhs r =
        case r of
          App (h, xs) => App (h, List.map twinAtom xs)
        (* a suspension's code, and what the runtime calls from C with one
           argument, stay closures of one parameter: thunk_make's, a
           foreign callback's, the runtime's (rt_); any other primitive's
           -- thunk_self_update's value, which a force gives after -- the
           twin *)
        | Prim (p, t, xs) =>
            if p = "thunk_make" orelse String.isPrefix "foreign" p orelse String.isPrefix "rt_" p then r
            else Prim (p, t, List.map twinAtom xs)
        | _ => mapRhs twinAtom r
      (* what a call's head is: a value (through its closure: any number of
         arguments), a local curried function with a twin of n
         parameters, or a function whose calls stay as they are *)
      datatype head = Value | Twin of atom * int | Stays
      fun headOf h =
        case h of
          Var (x, ts) =>
            (case IntTable.find (twins, x) of
               SOME (x2, n, global) => Twin (twinNamed (x2, ts, global), n)
             | NONE => if isSome (IntTable.find (localFuns, x)) then Stays else Value)
        (* a global this program declares by a value (Val, Do) holds a
           closure; one it declares a function, or one of another unit
           (--units), which may be a function whose calls are known, stays *)
        | Global (g, _) => if isSome (IntTable.find (valGlobals, g)) then Value else Stays
        | _ => Stays
      (* a step that may go before a call whose result is t: it names,
         makes, takes apart or casts a value, or makes a suspension, and
         names neither t nor a global; or functions that do not name t *)
      datatype moved = Moved of var * scheme * rhs | MovedFuns of fundef list
      fun names (t, r) = let val n = ref false in appAtomsOfRhs (fn Var (x, _) => if x = t then n := true else () | _ => ()) r; !n end
      fun early (t, r) = earlyShape r andalso ofNoGlobal r andalso not (names (t, r))
      fun earlyFuns (t, fs : fundef list) =
        let val u = IntTable.table 64 in List.app (fn f => Workers.count u (#body f)) fs; not (isSome (IntTable.find (u, t))) end
      (* a call, h applied to xs, its result t; and the calls after it that
         apply what it gives, used once, at once, with the steps between
         them that may go before the first (pre, the last first) *)
      fun chain (t, s, h, xs, rest) =
        let
          fun go (t, s, xs, rest, marks, pre) =
            case rest of
              Mark (sp, r) => go (t, s, xs, r, sp :: marks, pre)
            | Let (r, s2, App (Var (t', []), ys), rest2) =>
                if t' = t andalso usedOnce t andalso List.length (xs @ ys) <= maxArity then go (r, s2, xs @ ys, rest2, marks, pre)
                else stop (t, s, xs, rest, marks, pre)
            | Return (App (Var (t', []), ys)) =>
                if t' = t andalso usedOnce t andalso List.length (xs @ ys) <= maxArity
                then SOME (fn h => ahead (pre, remark (marks, Return (App (h, List.map twinAtom (xs @ ys))))), List.length (xs @ ys))
                else stop (t, s, xs, rest, marks, pre)
            | Let (y, s2, r, rest2) =>
                if early (t, r) then go (t, s, xs, rest2, marks, Moved (y, s2, r) :: pre) else stop (t, s, xs, rest, marks, pre)
            | Fun (fs, rest2) =>
                if earlyFuns (t, fs) then go (t, s, xs, rest2, marks, MovedFuns fs :: pre) else stop (t, s, xs, rest, marks, pre)
            | _ => stop (t, s, xs, rest, marks, pre)
          and stop (t, s, xs, rest, marks, pre) =
            if List.length xs < 2 then NONE
            else SOME (fn h => ahead (pre, Let (t, s, App (h, List.map twinAtom xs), remark (marks, exp rest))), List.length xs)
          and remark (marks, e) = List.foldl (fn (sp, e) => Mark (sp, e)) e marks
          and ahead (pre, e) = List.foldl (fn (Moved (y, s, r), e) => Let (y, s, rhs r, e) | (MovedFuns fs, e) => keep (List.map fundef fs, e)) e pre
          fun asIs () = Let (t, s, rhs (App (h, xs)), exp rest)
        in
          (* a call that stays is no chain's: go is asked of the others *)
          case headOf h of
            Stays => asIs ()
          | Value => (case go (t, s, xs, rest, [], []) of SOME (k, _) => k h | NONE => asIs ())
          | Twin (h2, n) =>
              (case go (t, s, xs, rest, [], []) of
                 SOME (k, m) =>
                   if m = n then ((case h of Var (x, _) => IntTable.bump (replaced, x) | _ => ()); k h2) else asIs ()
               | NONE => asIs ())
        end
      and exp e =
        case e of
          Let (t, s, App (h, xs), rest) => chain (t, s, h, xs, rest)
        | Let (x, s, r, b) => Let (x, s, rhs r, exp b)
        | Fun (fs, b) => let val fs = List.map fundef fs in keep (fs, exp b) end
        | Join (j, ps, body, s) => Join (j, ps, exp body, exp s)
        | Jump (j, xs) => Jump (j, List.map twinAtom xs)
        | If (c, a, b) => If (twinAtom c, exp a, exp b)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Raise a => Raise (twinAtom a)
        | Return r => Return (rhs r)
        | Mark (sp, a) => Mark (sp, exp a)
        | Case (a, arms, d) => let val (arms, d) = mapCase exp (arms, d) in Case (twinAtom a, arms, d) end
      and fundef ({name, label, tyvars, params, result, body} : fundef) : fundef =
        {name = name, label = label, tyvars = tyvars, params = params, result = result, body = exp body}
      (* a group of local functions, each rewritten, and the scope after it,
         where every use of them is: one with a twin named no more goes, and
         a group left empty, its functions' twins global workers *)
      and keep (fs : fundef list, scope : exp) : exp =
        let
          fun count (t, x) = case IntTable.find (t, x) of SOME n => n | NONE => 0
          fun named x = count (uses, x) > count (replaced, x)
        in
          case List.filter (fn f => named (#name f) orelse not (isSome (IntTable.find (twins, #name f)))) fs of
            [] => scope
          | fs' => Fun (fs', scope)
        end
    in
      List.map (fn Val (g, s, e) => Val (g, s, exp e) | Funs fs => Funs (List.map fundef fs) | Do (gs, e) => Do (gs, exp e)) p
    end
end
