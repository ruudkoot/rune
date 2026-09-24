(* What every Lambda the compiler makes keeps (docs/ir.md), checked after
   the stage that made it when --lint is given (Pass.stage):
   * every variable is used where a binder of it is in scope: a function's
     parameter, a let, a letrec, a handler;
   * every binder's stamp is bound once in the whole program, which the code
     generator relies on (its slots are by stamp);
   * every Fail is in tail position of the body of a Try of the same
     function, where it jumps to the Try's fallback with the stack as the
     Try found it;
   * every right-hand side of a letrec is a function.
   A breach is a bug of the compiler, raised as Error.Bug. *)
structure LambdaLint =
struct
  open Lambda

  fun check (e : lexp) : unit =
    let
      val bound : unit IntMap.map ref = ref IntMap.empty
      fun bind x =
        if IntMap.member (!bound, x) then Error.bug ("variable v" ^ Int.toString x ^ " is bound twice")
        else bound := IntMap.insert (!bound, x, ())
      fun isFn e = case unmark e of Fn _ => true | _ => false
      (* scope: the variables in scope; tail: whether a Fail here is in
         tail position of a Try's body *)
      fun go (e, scope : unit IntMap.map, tail : bool) : unit =
        case e of
          Var x => if IntMap.member (scope, x) then () else Error.bug ("variable v" ^ Int.toString x ^ " is not in scope")
        | Global _ => ()
        | Const _ => ()
        | Unit => ()
        | Fn (x, b) => (bind x; go (b, IntMap.insert (scope, x, ()), false))
        | App (f, a) => (go (f, scope, false); go (a, scope, false))
        | Let (x, a, b) => (go (a, scope, false); bind x; go (b, IntMap.insert (scope, x, ()), tail))
        | LetRec (bs, b) =>
            let
              val () = List.app (fn (x, _) => bind x) bs
              val scope' = List.foldl (fn ((x, _), m) => IntMap.insert (m, x, ())) scope bs
            in
              List.app (fn (x, r) =>
                          if isFn r then go (r, scope', false)
                          else Error.bug ("the letrec of v" ^ Int.toString x ^ " binds what is no function"))
                       bs;
              go (b, scope', tail)
            end
        | Seq (a, b) => (go (a, scope, false); go (b, scope, tail))
        | SetGlobal (_, a) => go (a, scope, false)
        | Tuple es => List.app (fn e => go (e, scope, false)) es
        | Select (_, a) => go (a, scope, false)
        | Con0 _ => ()
        | Con (_, a) => go (a, scope, false)
        | Decon a => go (a, scope, false)
        | ConTag a => go (a, scope, false)
        | If (c, t, f) => (go (c, scope, false); go (t, scope, tail); go (f, scope, tail))
        | Try (a, b) => (go (a, scope, true); go (b, scope, tail))
        | Fail => if tail then () else Error.bug "a Fail is not in tail position of a Try"
        | Raise a => go (a, scope, false)
        | Handle (a, x, h) => (go (a, scope, false); bind x; go (h, IntMap.insert (scope, x, ()), tail))
        | NewExn _ => ()
        | BuiltinExn _ => ()
        | MkExn (c, p) => (go (c, scope, false); go (p, scope, false))
        | ExnCon a => go (a, scope, false)
        | ExnArg a => go (a, scope, false)
        | Prim (_, args) => List.app (fn e => go (e, scope, false)) args
        | Mark (_, a) => go (a, scope, tail)
    in
      go (e, IntMap.empty, false)
    end
end
