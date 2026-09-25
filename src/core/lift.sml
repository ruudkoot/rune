(* Lambda lifting (docs/ir.md; docs/plans/middle-end.md, M8): a group of
   local functions none of which escapes -- each is only ever called, by
   name -- becomes a group of the top level. What the functions captured
   they are given instead, as parameters before their own, and every call
   passes it; so no closure of them is made, and every call of them is a
   known call (Lower's CallK), which the workers pass then flattens further.
   A group that captures nothing is lifted too, escaping or not: where it is
   used as a value it is the global, whose closure is made once, when the
   program starts, not each time the group was (a static closure, item 12
   of performance.md).

   * What a group is given is what is free in it, but that a function of
     another group lifted is what that one is given: a call of it must pass
     that on. Every one must abstract over no type variables, since a
     parameter cannot.
   * A lifted function abstracts over the type variables of the functions
     around it that its definition names, before its own, and every call
     gives them as themselves -- the call is inside those functions too.
   * It is named as the local function was (Translate.funNames), for
     traces. *)
structure Lift =
struct
  open Mid

  fun freshStamp () = Elaborate.freshStamp ()

  (* ---- what an expression names ---- *)

  fun atomsOfRhs (r : rhs) : atom list =
    case r of
      Atom a => [a]
    | App (f, xs) => f :: xs
    | Prim (_, _, xs) => xs
    | Tuple xs => xs
    | Select (_, a) => [a]
    | Con (_, _, a) => [a]
    | Decon (_, _, a) => [a]
    | ConTag a => [a]
    | MkExn (c, a) => [c, a]
    | ExnCon a => [a]
    | ExnArg (_, a) => [a]
    | SetGlobal (_, a) => [a]
    | _ => []

  (* What is free in each group of functions and the type variables it
     names, by its first member, worked out once: a group inside another is
     not walked again for the one around it. *)
  val groupFree : unit IntMap.map IntTable.table ref = ref (IntTable.table 16)
  val groupGens : unit IntMap.map IntTable.table ref = ref (IntTable.table 16)

  fun memo (t : unit IntMap.map IntTable.table ref, fs : fundef list, compute : unit -> unit IntMap.map) =
    case fs of
      f :: _ =>
        (case IntTable.find (!t, #name f) of
           SOME s => s
         | NONE => let val s = compute () in IntTable.insert (!t, #name f, s); s end)
    | [] => IntMap.empty

  (* The variables free in e, bound left out, added to acc. *)
  fun free (e : exp, bound : unit IntMap.map, acc : unit IntMap.map) : unit IntMap.map =
    let
      fun atom (a, acc) =
        case a of
          Var (x, _) => if IntMap.member (bound, x) then acc else IntMap.insert (acc, x, ())
        | _ => acc
      fun bind (x, b) = IntMap.insert (b, x, ())
    in
      case e of
        Let (x, _, r, b) => free (b, bind (x, bound), List.foldl atom acc (atomsOfRhs r))
      | Fun (fs, b) =>
          let
            val bound' = List.foldl (fn (f, m) => bind (#name f, m)) bound fs
            val inGroup = groupFreeOf fs
            val acc = IntMap.foldli (fn (x, (), acc) => if IntMap.member (bound, x) then acc else IntMap.insert (acc, x, ()))
                                    acc inGroup
          in free (b, bound', acc) end
      | Join (_, ps, body, s) => free (s, bound, free (body, List.foldl (fn ((x, _), m) => bind (x, m)) bound ps, acc))
      | Jump (_, xs) => List.foldl atom acc xs
      | If (c, t, f) => free (f, bound, free (t, bound, atom (c, acc)))
      | Handle (a, x, h) => free (h, bind (x, bound), free (a, bound, acc))
      | Raise a => atom (a, acc)
      | Return r => List.foldl atom acc (atomsOfRhs r)
      | Mark (_, a) => free (a, bound, acc)
    end
  and freeFun (f : fundef, bound, acc) =
    free (#body f, List.foldl (fn ((x, _), m) => IntMap.insert (m, x, ())) bound (#params f), acc)

  (* what is free in a group, its members' names left out *)
  and groupFreeOf (fs : fundef list) : unit IntMap.map =
    memo (groupFree, fs, fn () =>
            let val names = List.foldl (fn (f, m) => IntMap.insert (m, #name f, ())) IntMap.empty fs
            in List.foldl (fn (f, acc) => freeFun (f, names, acc)) IntMap.empty fs end)

  (* The generic type variables a type names, added to acc. *)
  fun gensOfTy (t : Ty.ty, acc : unit IntMap.map) : unit IntMap.map =
    case t of
      Ty.Gen i => IntMap.insert (acc, i, ())
    | Ty.Con (_, _, ts) => List.foldl gensOfTy acc ts
    | Ty.Tuple ts => List.foldl gensOfTy acc ts
    | Ty.Arrow (a, b) => gensOfTy (b, gensOfTy (a, acc))
    | _ => acc

  (* ... and those an expression names *)
  fun gensOf (e : exp, acc : unit IntMap.map) : unit IntMap.map =
    let
      fun atom (a, acc) =
        case a of
          Var (_, ts) => List.foldl gensOfTy acc ts
        | Global (_, ts) => List.foldl gensOfTy acc ts
        | Const (_, t) => gensOfTy (t, acc)
        | Con0 (_, t) => gensOfTy (t, acc)
        | Unit => acc
      fun rhs (r, acc) =
        let
          val acc = List.foldl atom acc (atomsOfRhs r)
        in
          case r of
            Prim (_, t, _) => gensOfTy (t, acc)
          | Con (_, t, _) => gensOfTy (t, acc)
          | ExnArg (t, _) => gensOfTy (t, acc)
          | _ => acc
        end
    in
      case e of
        Let (_, (_, t), r, b) => gensOf (b, rhs (r, gensOfTy (t, acc)))
      | Fun (fs, b) => gensOf (b, IntMap.unionWith #1 (acc, groupGensOf fs))
      | Join (_, ps, body, s) => gensOf (s, gensOf (body, List.foldl (fn ((_, t), acc) => gensOfTy (t, acc)) acc ps))
      | Jump (_, xs) => List.foldl atom acc xs
      | If (c, t, f) => gensOf (f, gensOf (t, atom (c, acc)))
      | Handle (a, _, h) => gensOf (h, gensOf (a, acc))
      | Raise a => atom (a, acc)
      | Return r => rhs (r, acc)
      | Mark (_, a) => gensOf (a, acc)
    end
  and gensOfFun (f : fundef, acc) =
    gensOf (#body f, gensOfTy (#result f, List.foldl (fn ((_, t), acc) => gensOfTy (t, acc)) acc (#params f)))
  and groupGensOf (fs : fundef list) : unit IntMap.map =
    memo (groupGens, fs, fn () => List.foldl gensOfFun IntMap.empty fs)

  (* Whether e makes a local function: a definition that does not has
     nothing to lift, and is neither scanned nor rewritten. *)
  fun hasFun (e : exp) : bool =
    case e of
      Let (_, _, _, b) => hasFun b
    | Fun _ => true
    | Join (_, _, body, s) => hasFun body orelse hasFun s
    | If (_, t, f) => hasFun t orelse hasFun f
    | Handle (a, _, h) => hasFun a orelse hasFun h
    | Mark (_, a) => hasFun a
    | _ => false

  fun defHasFun (d : def) : bool =
    case d of
      Val (_, _, e) => hasFun e
    | Funs fs => List.exists (fn f => hasFun (#body f)) fs
    | Do (_, e) => hasFun e

  (* ---- the program ---- *)

  fun program (p : program) : program =
    let
      val () = (groupFree := IntTable.table 256; groupGens := IntTable.table 256)
      (* every binder's scheme, and how each variable is used: in all, and
         as the function of a call *)
      val schemes : scheme IntTable.table = IntTable.table 4096
      val allUses : int IntTable.table = IntTable.table 4096
      val calls : int IntTable.table = IntTable.table 4096
      (* counted only for local functions, whose names come before their uses *)
      val funs : unit IntTable.table = IntTable.table 1024
      fun bump (t, x) =
        if isSome (IntTable.find (funs, x)) then IntTable.insert (t, x, 1 + (case IntTable.find (t, x) of SOME n => n | NONE => 0))
        else ()
      fun useAtom a = case a of Var (x, _) => bump (allUses, x) | _ => ()
      fun scan e =
        case e of
          Let (x, s, r, b) =>
            (IntTable.insert (schemes, x, s);
             List.app useAtom (atomsOfRhs r);
             case r of App (Var (f, _), _) => bump (calls, f) | _ => ();
             scan b)
        | Fun (fs, b) => (List.app (fn f => IntTable.insert (funs, #name f, ())) fs; List.app scanFun fs; scan b)
        | Join (_, ps, body, s) => (List.app (fn (x, t) => IntTable.insert (schemes, x, ([], t))) ps; scan body; scan s)
        | Jump (_, xs) => List.app useAtom xs
        | If (c, t, f) => (useAtom c; scan t; scan f)
        | Handle (a, x, h) => (IntTable.insert (schemes, x, ([], Ty.exn)); scan a; scan h)
        | Raise a => useAtom a
        | Return r =>
            (List.app useAtom (atomsOfRhs r);
             case r of App (Var (f, _), _) => bump (calls, f) | _ => ())
        | Mark (_, a) => scan a
      and scanFun (f : fundef) =
        (IntTable.insert (schemes, #name f, (#tyvars f, funTy f));
         List.app (fn (x, t) => IntTable.insert (schemes, x, ([], t))) (#params f);
         scan (#body f))
      (* only the definitions that make local functions: a variable is bound
         in the definition it is used in *)
      val withFun = List.map (fn d => (d, defHasFun d)) p
      val () = List.app (fn (Val (_, _, e), true) => scan e
                          | (Funs fs, true) => List.app scanFun fs
                          | (Do (_, e), true) => scan e
                          | _ => ()) withFun
      fun count (t, x) = case IntTable.find (t, x) of SOME n => n | NONE => 0
      fun onlyCalled x = count (allUses, x) = count (calls, x)

      (* The groups lifted, by each member's name: the global it becomes,
         what the group is given (the variables, in order), and the type
         variables around it that it abstracts over. Found outside in, so
         that a group's is known before any group inside its scope asks. *)
      type lifted = {global : var, extra : var list, outer : int list}
      val lifted : lifted IntTable.table = IntTable.table 256
      val found = ref 0
      fun monomorphic x = case IntTable.find (schemes, x) of SOME ([], _) => true | _ => false
      fun find e =
        case e of
          Let (_, _, _, b) => find b
        | Fun (fs, b) =>
            (let
                 val fv = groupFreeOf fs
                 (* a function of a group lifted before is what it is given *)
                 val extra =
                   IntMap.foldli (fn (x, (), acc) =>
                                    case IntTable.find (lifted, x) of
                                      SOME {extra, ...} => List.foldl (fn (y, acc) => IntMap.insert (acc, y, ())) acc extra
                                    | NONE => IntMap.insert (acc, x, ()))
                                 IntMap.empty fv
                 val extra = IntMap.listKeys extra
               in
                 if (null extra orelse List.all (fn f => onlyCalled (#name f)) fs) andalso List.all monomorphic extra
                    andalso List.all (fn f => List.length extra + List.length (#params f) <= #maxArgs Target.stack) fs
                    andalso Pass.spend () then
                   let
                     val own = List.foldl (fn (f, m) => List.foldl (fn (a, m) => IntMap.insert (m, a, ())) m (#tyvars f))
                                          IntMap.empty fs
                     val gens = groupGensOf fs
                     val gens = List.foldl (fn (x, acc) => case IntTable.find (schemes, x) of
                                                             SOME (_, t) => gensOfTy (t, acc)
                                                           | NONE => acc) gens extra
                     val outer = List.filter (fn a => not (IntMap.member (own, a))) (IntMap.listKeys gens)
                   in
                     List.app (fn f => IntTable.insert (lifted, #name f, {global = freshStamp (), extra = extra, outer = outer}))
                              fs;
                     found := !found + 1
                   end
                 else ()
               end;
             List.app (fn f => find (#body f)) fs;
             find b)
        | Join (_, _, body, s) => (find body; find s)
        | If (_, t, f) => (find t; find f)
        | Handle (a, _, h) => (find a; find h)
        | Mark (_, a) => find a
        | _ => ()
      (* each definition, and whether it lifts anything *)
      val marked =
        List.map (fn (d, false) => (d, false)
                   | (d, true) =>
                       let val was = !found
                       in
                         case d of
                           Val (_, _, e) => find e
                         | Funs fs => List.app (fn f => find (#body f)) fs
                         | Do (_, e) => find e;
                         (d, !found > was)
                       end) withFun

      (* ---- the rewriting ---- *)

      (* the groups taken out of the definition being rewritten *)
      val out : fundef list list ref = ref []

      (* a call of a lifted function: its global, at the variables around it
         and its own, given what it is given and its arguments *)
      fun call (f, ts, args) =
        case IntTable.find (lifted, f) of
          SOME {global, extra, outer} =>
            SOME (App (Global (global, List.map Ty.Gen outer @ ts), List.map (fn x => Var (x, [])) extra @ args))
        | NONE => NONE
      (* a lifted function that is given nothing, as a value: the global *)
      fun atom a =
        case a of
          Var (f, ts) =>
            (case IntTable.find (lifted, f) of
               SOME {global, extra = [], outer} => Global (global, List.map Ty.Gen outer @ ts)
             | _ => a)
        | _ => a
      fun rhs r =
        case r of
          Atom a => Atom (atom a)
        | App (Var (f, ts), args) =>
            (case call (f, ts, List.map atom args) of SOME r' => r' | NONE => App (Var (f, ts), List.map atom args))
        | App (f, xs) => App (atom f, List.map atom xs)
        | Prim (q, t, xs) => Prim (q, t, List.map atom xs)
        | Tuple xs => Tuple (List.map atom xs)
        | Select (i, a) => Select (i, atom a)
        | Con (tag, t, a) => Con (tag, t, atom a)
        | Decon (tag, t, a) => Decon (tag, t, atom a)
        | ConTag a => ConTag (atom a)
        | MkExn (c, a) => MkExn (atom c, atom a)
        | ExnCon a => ExnCon (atom a)
        | ExnArg (t, a) => ExnArg (t, atom a)
        | SetGlobal (g, a) => SetGlobal (g, atom a)
        | _ => r

      (* e with each atom's variable renamed where s says *)
      fun rename (s : var IntMap.map) (e : exp) : exp =
        let
          fun atom a = case a of Var (x, ts) => (case IntMap.find (s, x) of SOME y => Var (y, ts) | NONE => a) | _ => a
          fun r' r =
            case r of
              Atom a => Atom (atom a)
            | App (f, xs) => App (atom f, List.map atom xs)
            | Prim (q, t, xs) => Prim (q, t, List.map atom xs)
            | Tuple xs => Tuple (List.map atom xs)
            | Select (i, a) => Select (i, atom a)
            | Con (tag, t, a) => Con (tag, t, atom a)
            | Decon (tag, t, a) => Decon (tag, t, atom a)
            | ConTag a => ConTag (atom a)
            | MkExn (c, a) => MkExn (atom c, atom a)
            | ExnCon a => ExnCon (atom a)
            | ExnArg (t, a) => ExnArg (t, atom a)
            | SetGlobal (g, a) => SetGlobal (g, atom a)
            | _ => r
          fun go e =
            case e of
              Let (x, sc, r, b) => Let (x, sc, r' r, go b)
            | Fun (fs, b) =>
                Fun (List.map (fn {name, tyvars, params, result, body} =>
                                 {name = name, tyvars = tyvars, params = params, result = result, body = go body}) fs,
                     go b)
            | Join (j, ps, body, sc) => Join (j, ps, go body, go sc)
            | Jump (j, xs) => Jump (j, List.map atom xs)
            | If (c, t, f) => If (atom c, go t, go f)
            | Handle (a, x, h) => Handle (go a, x, go h)
            | Raise a => Raise (atom a)
            | Return r => Return (r' r)
            | Mark (sp, a) => Mark (sp, go a)
        in go e end

      fun exp e =
        case e of
          Let (x, s, r, b) => Let (x, s, rhs r, exp b)
        | Fun (fs, b) =>
            (case fs of
               f :: _ =>
                 if isSome (IntTable.find (lifted, #name f)) then (out := List.map lift fs :: !out; exp b)
                 else Fun (List.map fundef fs, exp b)
             | [] => exp b)
        | Join (j, ps, body, sc) => Join (j, ps, exp body, exp sc)
        | Jump (j, xs) => Jump (j, List.map atom xs)
        | If (c, t, f) => If (atom c, exp t, exp f)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Raise a => Raise (atom a)
        | Return r => Return (rhs r)
        | Mark (sp, a) => Mark (sp, exp a)
      and fundef ({name, tyvars, params, result, body} : fundef) : fundef =
        {name = name, tyvars = tyvars, params = params, result = result, body = exp body}

      (* a member of a lifted group, as a function of the top level: what it
         is given its first parameters, renamed in its body *)
      and lift ({name, tyvars, params, result, body} : fundef) : fundef =
        let
          val {global, extra, outer} = valOf (IntTable.find (lifted, name))
          val fresh = List.map (fn x => (x, freshStamp ())) extra
          val s = List.foldl (fn ((x, y), m) => IntMap.insert (m, x, y)) IntMap.empty fresh
          val ps = List.map (fn (x, y) => (y, case IntTable.find (schemes, x) of SOME (_, t) => t | NONE => Ty.unit)) fresh
          (* named as it was, by its first parameter now *)
          val () =
            case (fresh, params) of
              ((_, y) :: _, (x, _) :: _) =>
                (case IntMap.find (!Translate.funNames, x) of
                   SOME n => Translate.funNames := IntMap.insert (!Translate.funNames, y, n)
                 | NONE => ())
            | _ => ()
        in
          {name = global, tyvars = outer @ tyvars, params = ps @ params, result = result, body = rename s (exp body)}
        end

      fun def d =
        let
          val () = out := []
          val d' =
            case d of
              Val (g, s, e) => Val (g, s, exp e)
            | Funs fs => Funs (List.map fundef fs)
            | Do (gs, e) => Do (gs, exp e)
        in
          List.rev (d' :: List.map Funs (!out))
        end
    in
      if !found = 0 then p else List.concat (List.map (fn (d, true) => def d | (d, false) => [d]) marked)
    end
end
