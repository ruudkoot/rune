(* Workers and wrappers (docs/ir.md; docs/plans/middle-end.md, M8 and D9):
   a function of the top level that takes its arguments in a tuple, or one
   at a time (curried), becomes two. The worker takes them all as its
   parameters and does what the function did; the wrapper, the function as
   it was, takes them as it did and calls the worker, for the uses of the
   function as a value.

   * Flattened: a function with a parameter that is a tuple it only takes
     apart. Every call of it calls the worker with the fields of that
     argument (Select), which the simplifier then finds where the tuple was
     made -- so that it is not made.
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

  fun freshStamp () = Elaborate.freshStamp ()

  (* Whether x is used in e only as the tuple of a Select. *)
  fun onlySelected (x : var, e : exp) : bool =
    let
      fun ok a = case a of Var (y, _) => y <> x | _ => true
      fun oks xs = List.all ok xs
      fun rhs r =
        case r of
          Atom a => ok a
        | App (f, xs) => oks (f :: xs)
        | Prim (_, _, xs) => oks xs
        | Tuple xs => oks xs
        | Select _ => true
        | Con (_, _, a) => ok a
        | Decon (_, _, a) => ok a
        | ConTag a => ok a
        | MkExn (c, a) => oks [c, a]
        | ExnCon a => ok a
        | ExnArg (_, a) => ok a
        | SetGlobal (_, a) => ok a
        | _ => true
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
    in exp e end

  (* How often each variable is used in e, added to the table. *)
  fun count (uses : int IntTable.table) (e : exp) : unit =
    let
      fun atom a =
        case a of
          Var (x, _) => IntTable.bump (uses, x)
        | _ => ()
      fun rhs r =
        case r of
          Atom a => atom a
        | App (f, xs) => List.app atom (f :: xs)
        | Prim (_, _, xs) => List.app atom xs
        | Tuple xs => List.app atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, _, a) => atom a
        | ConTag a => atom a
        | MkExn (c, a) => (atom c; atom a)
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (_, a) => atom a
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
    in exp e end

  fun unmark (Mark (_, e)) = unmark e
    | unmark e = e

  (* The levels of a curried function: each one's parameters -- the
     function's own, then one for each function inside -- and the type of
     what it returns, and the body of the innermost. A level's function
     abstracts over no type variables and names itself nowhere. *)
  fun levels (f : fundef) : ((var * Ty.ty) list * Ty.ty) list * exp =
    let
      fun mentions (x, e) =
        let val t = IntTable.table 16
        in count t e; isSome (IntTable.find (t, x)) end
      fun go (acc, e) =
        case unmark e of
          Fun ([{name, tyvars = [], params = [p], result, body}], Return (Atom (Var (n, [])))) =>
            if n = name andalso not (mentions (name, body)) then go (([p], result) :: acc, body)
            else (List.rev acc, e)
        | _ => (List.rev acc, e)
    in
      go ([(#params f, #result f)], #body f)
    end

  datatype shape =
      Flat of Ty.ty list option list      (* for each parameter, its fields where it is flattened *)
    | Curried of ((var * Ty.ty) list * Ty.ty) list * exp  (* the levels, and the innermost body *)

  type worker = {worker : var, tyvars : int list, shape : shape}

  fun program (p : program) : program =
    let
      (* the functions that get a worker, by name; each is one rewrite *)
      fun fits n = n <= #maxArgs Target.stack
      fun candidate (f as {name, tyvars, params, body, ...} : fundef, m) =
        case levels f of
          (ls as _ :: _ :: _, inner) =>
            if fits (List.foldl (fn ((ps, _), n) => n + List.length ps) 0 ls) andalso Pass.spend () then
              IntMap.insert (m, name, {worker = freshStamp (), tyvars = tyvars, shape = Curried (ls, inner)})
            else m
        | _ =>
            let
              val specs =
                List.map (fn (x, Ty.Tuple ts) => if List.length ts >= 2 andalso onlySelected (x, body) then SOME ts else NONE
                           | _ => NONE) params
              val arity = List.foldl (fn (SOME ts, n) => n + List.length ts | (NONE, n) => n + 1) 0 specs
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
          and rhs r =
            case r of
              Atom a => atom a
            | App (f, xs) => List.app atom (f :: xs)
            | Prim (_, _, xs) => List.app atom xs
            | Tuple xs => List.app atom xs
            | Select (_, a) => atom a
            | Con (_, _, a) => atom a
            | Decon (_, _, a) => atom a
            | ConTag a => atom a
            | MkExn (c, a) => (atom c; atom a)
            | ExnCon a => atom a
            | ExnArg (_, a) => atom a
            | SetGlobal (_, a) => atom a
            | _ => ()
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

      (* A call of a flattened function: the fields of each argument it
         flattens, each in a variable, and the worker's call in k. *)
      fun flat ({worker, tyvars, ...} : worker, specs, ts, args, k : rhs -> exp) : exp =
        let
          val s = ListPair.foldl (fn (v, t, s) => IntMap.insert (s, v, t)) IntMap.empty (tyvars, ts)
          fun each ((a, NONE), (args, lets)) = (a :: args, lets)
            | each ((a, SOME fields), (args, lets)) =
                let
                  val xs = List.map (fn t => (freshStamp (), Ty.subst s t)) fields
                  val (_, lets) =
                    List.foldl (fn ((x, t), (i, lets)) => (i + 1, fn e => lets (Let (x, ([], t), Select (i, a), e))))
                               (0, lets) xs
                in (List.revAppend (List.map (fn (x, _) => Var (x, [])) xs, args), lets) end
          val (args', lets) = List.foldl each ([], fn e => e) (ListPair.zip (args, specs))
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
        | _ => e
      and fundef ({name, tyvars, params, result, body} : fundef) : fundef =
        {name = name, tyvars = tyvars, params = params, result = result, body = exp body}

      (* a new parameter named as the one it stands for, for traces *)
      fun renamed (x : var) : var =
        let val x' = freshStamp ()
        in
          case IntMap.find (!Translate.funNames, x) of
            SOME n => Translate.funNames := IntMap.insert (!Translate.funNames, x', n)
          | NONE => ();
          x'
        end

      (* A function with a worker: the worker and the wrapper. *)
      fun split (f as {name, tyvars, params, result, body} : fundef) : fundef list =
        case IntMap.find (workers, name) of
          SOME {worker, shape = Flat specs, ...} =>
            let
              (* the worker's parameters: one kept as it is, and the fields
                 of one flattened where the function took it apart *)
              val ps = ListPair.zip (params, specs)
              val fields : (var * var list) list =
                List.mapPartial (fn ((x, _), SOME ts) => SOME (x, List.map (fn _ => renamed x) ts) | _ => NONE) ps
              fun field (x, i) =
                case List.find (fn (y, _) => y = x) fields of
                  SOME (_, ys) => SOME (Var (List.nth (ys, i), []))
                | NONE => NONE
              fun sel e =
                case e of
                  Let (v, s, r as Select (i, Var (x', _)), b) =>
                    (case field (x', i) of SOME a => Let (v, s, Atom a, sel b) | NONE => Let (v, s, r, sel b))
                | Let (v, s, r, b) => Let (v, s, r, sel b)
                | Fun (fs, b) =>
                    Fun (List.map (fn {name, tyvars, params, result, body} =>
                                     {name = name, tyvars = tyvars, params = params, result = result, body = sel body}) fs,
                         sel b)
                | Join (j, ps, jb, sc) => Join (j, ps, sel jb, sel sc)
                | If (c, t, e) => If (c, sel t, sel e)
                | Handle (a, v, h) => Handle (sel a, v, sel h)
                | Return (Select (i, Var (x', _))) => (case field (x', i) of SOME a => Return (Atom a) | NONE => e)
                | Mark (sp, a) => Mark (sp, sel a)
                | _ => e
              val workerParams =
                List.concat (List.map (fn ((x, t), NONE) => [(x, t)]
                                        | ((x, _), SOME ts) => ListPair.zip (#2 (valOf (List.find (fn (y, _) => y = x) fields)), ts))
                                      ps)
              val workerDef = {name = worker, tyvars = tyvars, params = workerParams, result = result, body = sel (exp body)}
              (* the wrapper: a kept parameter renamed and passed on, a
                 flattened one taken apart *)
              val wrapperParams = List.map (fn ((x, t), NONE) => (renamed x, t) | ((x, t), SOME _) => (x, t)) ps
              val (args, lets) =
                ListPair.foldl
                  (fn (((x, _), NONE), _, (args, lets)) => (Var (x, []) :: args, lets)
                    | (((x, _), SOME ts), _, (args, lets)) =>
                        let
                          val zs = List.map (fn t => (freshStamp (), t)) ts
                          val (_, lets) =
                            List.foldl (fn ((z, t), (i, lets)) => (i + 1, fn e => lets (Let (z, ([], t), Select (i, Var (x, [])), e))))
                                       (0, lets) zs
                        in (List.revAppend (List.map (fn (z, _) => Var (z, [])) zs, args), lets) end)
                  ([], fn e => e) (ListPair.zip (wrapperParams, specs), ps)
              val call = App (Global (worker, List.map Ty.Gen tyvars), List.rev args)
            in
              [workerDef, {name = name, tyvars = tyvars, params = wrapperParams, result = result, body = lets (Return call)}]
            end
        | SOME {worker, shape = Curried (ls, inner), ...} =>
            let
              (* the worker has every level's parameters and the innermost
                 body; the wrapper takes them level by level again, in
                 closures of its own *)
              val workerDef = {name = worker, tyvars = tyvars, params = List.concat (List.map #1 ls),
                               result = #2 (List.last ls), body = exp inner}
              val ls' = List.map (fn (ps, r) => (List.map (fn (x, t) => (renamed x, t)) ps, r)) ls
              val call = App (Global (worker, List.map Ty.Gen tyvars),
                              List.map (fn (x, _) => Var (x, [])) (List.concat (List.map #1 ls')))
              fun level [] = Return call
                | level ((ps, r) :: rest) =
                    let val g = freshStamp ()
                    in Fun ([{name = g, tyvars = [], params = ps, result = r, body = level rest}], Return (Atom (Var (g, [])))) end
            in
              [workerDef, {name = name, tyvars = tyvars, params = #1 (hd ls'), result = #2 (hd ls'), body = level (tl ls')}]
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
          (* a wrapper nothing names now, every call being the worker's, goes *)
          fun times (t, x) = case IntTable.find (t, x) of SOME n => n | NONE => 0
          fun wanted (f : fundef) =
            not (IntMap.member (workers, #name f)) orelse times (refs, #name f) > times (redirected, #name f)
        in
          List.mapPartial (fn Funs fs => (case List.filter wanted fs of [] => NONE | fs' => SOME (Funs fs'))
                            | d => SOME d) p'
        end
    end
end
