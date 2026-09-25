(* The simplifier (docs/ir.md; docs/plans/middle-end.md, M7): shrinking
   reductions on Mid, which leave it no larger (Appel and Jim 1997), in a
   few rounds, each after a census of the uses of every variable, join point
   and function:
   * a variable bound to an atom is the atom, where it abstracts over no
     type variables;
   * a step nothing uses is dropped where it has no effect (Prims.removable);
   * what is known is used: the tag of a constructor made in the same
     function, a field of a tuple or constructor made there, an If on a
     known bool;
   * a primitive of int, word or char on constants is folded, at the
     target's precision (Target.t's intBits), unless it would raise, which
     is left to run;
   * a join point nothing jumps to goes, and one jumped to once is put
     where the jump is;
   * a join point that tests its one parameter, a bool, where a jump gives
     it a constant, is two, one for each branch, and the jump goes to its
     branch's -- andalso and orelse as branches;
   * a raise in a handler's region, in the region's own code, is a jump to
     the handler, which becomes a join point;
   * a function nothing uses goes, and one called once, where it is made,
     is put where the call is;
   * a function that only calls another with its parameter is the other
     (eta), where it abstracts over no type variables.
   Every rewrite asks Pass.spend first, so that --fuel can find one that
   breaks a program. The types are kept: what is put in a variable's place
   has its type, and a function put in place is at the types it is called
   at. *)
structure Simplify =
struct
  open Mid

  fun bug msg = Error.bug ("Simplify: " ^ msg)

  (* Pass.spend, and whether this round has rewritten anything: a round
     that has not is the last. *)
  val changed = ref false
  fun spend () = Pass.spend () andalso (changed := true; true)

  (* ---- the census ---- *)

  (* The uses of every variable and the jumps to every join point of an
     expression. Stamps are unique, so the census, and what a round knows
     of each variable, are tables of stamps, which are only asked (IntTable). *)
  type census = {vars : int IntTable.table, labels : int IntTable.table}

  fun bump (t, k) = IntTable.insert (t, k, 1 + (case IntTable.find (t, k) of SOME n => n | NONE => 0))

  fun census (e : exp) : census =
    let
      val c as {vars, labels} = {vars = IntTable.table 64, labels = IntTable.table 16}
      fun atom a = case a of Var (x, _) => bump (vars, x) | _ => ()
      fun rhs r =
        case r of
          Atom a => atom a
        | App (f, xs) => (atom f; List.app atom xs)
        | Prim (_, _, xs) => List.app atom xs
        | Tuple xs => List.app atom xs
        | Select (_, a) => atom a
        | Con (_, _, a) => atom a
        | Decon (_, a) => atom a
        | ConTag a => atom a
        | MkExn (x, y) => (atom x; atom y)
        | ExnCon a => atom a
        | ExnArg (_, a) => atom a
        | SetGlobal (_, a) => atom a
        | _ => ()
      fun exp e =
        case e of
          Let (_, _, r, b) => (rhs r; exp b)
        | Fun (fs, b) => (List.app (fn f => exp (#body f)) fs; exp b)
        | Join (_, _, body, s) => (exp body; exp s)
        | Jump (j, xs) => (List.app atom xs; bump (labels, j))
        | If (a, t, f) => (atom a; exp t; exp f)
        | Handle (a, _, h) => (exp a; exp h)
        | Raise a => atom a
        | Return r => rhs r
        | Mark (_, a) => exp a
    in
      exp e; c
    end

  fun uses (c : census, x) = case IntTable.find (#vars c, x) of SOME n => n | NONE => 0
  fun jumps (c : census, j) = case IntTable.find (#labels c, j) of SOME n => n | NONE => 0

  (* ---- what may go ---- *)

  (* A step that may be dropped where nothing uses its value: it has no
     effect but to make that value. A deconstruction or a field is only made
     where the translation has tested what it takes apart. *)
  fun removable (r : rhs) : bool =
    case r of
      Atom _ => true
    | App _ => false
    | Prim (p, _, _) => Prims.removable p
    | SetGlobal _ => false
    | _ => true

  (* ---- constants ---- *)

  val bits = #intBits Target.stack
  val half = IntInf.pow (IntInf.fromInt 2, bits - 1)
  val full = IntInf.pow (IntInf.fromInt 2, bits)
  fun fitsInt i = IntInf.>= (i, IntInf.~ half) andalso IntInf.< (i, half)
  fun wrapWord w = IntInf.mod (w, full)

  fun boolAtom b = Con0 (if b then 1 else 0, Ty.bool)

  (* A primitive of constants, where its result is known and it does not
     raise: an atom. *)
  fun fold (p : string, pty : Ty.ty, xs : atom list) : atom option =
    let
      val result = case pty of Ty.Arrow (_, r) => r | _ => Ty.int
      fun ints () = case xs of [Const (Lambda.CInt a, _), Const (Lambda.CInt b, _)] => SOME (a, b) | _ => NONE
      fun words () = case xs of [Const (Lambda.CWord a, _), Const (Lambda.CWord b, _)] => SOME (a, b) | _ => NONE
      fun int f = case ints () of
                    SOME (a, b) => let val r = f (a, b) in if fitsInt r then SOME (Const (Lambda.CInt r, result)) else NONE end
                  | NONE => NONE
      fun intCmp f = case ints () of SOME (a, b) => SOME (boolAtom (f (a, b))) | NONE => NONE
      fun word f = case words () of SOME (a, b) => SOME (Const (Lambda.CWord (wrapWord (f (a, b))), result)) | NONE => NONE
      fun wordCmp f = case words () of SOME (a, b) => SOME (boolAtom (f (a, b))) | NONE => NONE
    in
      case p of
        "int_add" => int IntInf.+
      | "int_sub" => int IntInf.-
      | "int_mul" => int IntInf.*
      | "int_lt" => intCmp IntInf.<
      | "int_le" => intCmp IntInf.<=
      | "int_gt" => intCmp IntInf.>
      | "int_ge" => intCmp IntInf.>=
      | "word_add" => word IntInf.+
      | "word_sub" => word IntInf.-
      | "word_mul" => word IntInf.*
      | "word_lt" => wordCmp IntInf.<
      | "word_le" => wordCmp IntInf.<=
      | "word_gt" => wordCmp IntInf.>
      | "word_ge" => wordCmp IntInf.>=
      | "poly_eq" =>
          (case xs of
             [Const (Lambda.CInt a, _), Const (Lambda.CInt b, _)] => SOME (boolAtom (a = b))
           | [Const (Lambda.CWord a, _), Const (Lambda.CWord b, _)] => SOME (boolAtom (a = b))
           | [Const (Lambda.CChar a, _), Const (Lambda.CChar b, _)] => SOME (boolAtom (a = b))
           | [Con0 (a, _), Con0 (b, _)] => SOME (boolAtom (a = b))
           | _ => NONE)
      | "ptr_eq" =>
          (case xs of
             [Global (a, []), Global (b, [])] => if a = b then SOME (boolAtom true) else NONE
           | [Var (a, []), Var (b, [])] => if a = b then SOME (boolAtom true) else NONE
           | _ => NONE)
      | _ => NONE
    end

  (* ---- the rewriting ---- *)

  (* What a variable is known to be: a step that made it, of those whose
     parts can be read back. *)
  datatype known = Made of rhs

  (* What a round knows: the atom each variable it has dropped is, and what
     made each variable whose parts can be read back. A variable is used only
     where it is in scope, so neither need forget. *)
  type env = {subst : atom IntTable.table, known : known IntTable.table}

  fun substAtom (env : env, a : atom) : atom =
    case a of
      Var (x, []) => (case IntTable.find (#subst env, x) of SOME b => b | NONE => a)
    | _ => a

  fun substRhs (env, r : rhs) : rhs =
    let fun at a = substAtom (env, a)
    in
      case r of
        Atom a => Atom (at a)
      | App (f, xs) => App (at f, List.map at xs)
      | Prim (p, t, xs) => Prim (p, t, List.map at xs)
      | Tuple xs => Tuple (List.map at xs)
      | Select (i, a) => Select (i, at a)
      | Con (tag, t, a) => Con (tag, t, at a)
      | Decon (tag, a) => Decon (tag, at a)
      | ConTag a => ConTag (at a)
      | MkExn (c, a) => MkExn (at c, at a)
      | ExnCon a => ExnCon (at a)
      | ExnArg (t, a) => ExnArg (t, at a)
      | SetGlobal (g, a) => SetGlobal (g, at a)
      | _ => r
    end

  (* What a step is, now that what is known is used: an atom where it can
     be. *)
  fun known (env : env, r : rhs) : rhs =
    let
      fun madeOf (Var (x, [])) = IntTable.find (#known env, x)
        | madeOf _ = NONE
    in
      case r of
        Select (i, a) =>
          (case madeOf a of
             SOME (Made (Tuple xs)) => if i < List.length xs andalso spend () then Atom (List.nth (xs, i)) else r
           | _ => r)
      | Decon (tag, a) =>
          (case madeOf a of
             SOME (Made (Con (tag', _, x))) => if tag = tag' andalso spend () then Atom x else r
           | _ => r)
      | ExnCon a =>
          (case madeOf a of
             SOME (Made (MkExn (con, _))) => if spend () then Atom con else r
           | _ => r)
      | ConTag a =>
          (case (a, madeOf a) of
             (Con0 (tag, _), _) => if spend () then Atom (Const (Lambda.CInt (IntInf.fromInt tag), Ty.int)) else r
           | (_, SOME (Made (Con (tag, _, _)))) =>
               if spend () then Atom (Const (Lambda.CInt (IntInf.fromInt tag), Ty.int)) else r
           | _ => r)
      | Prim (p, t, xs) =>
          (case fold (p, t, xs) of
             SOME a => if spend () then Atom a else r
           | NONE => r)
      | _ => r
    end

  (* e with f applied to every atom, and ty to every type it says. *)
  fun mapExp (f : atom -> atom, ty : Ty.ty -> Ty.ty) (e : exp) : exp =
    let
      fun rhs r =
        case r of
          Atom a => Atom (f a)
        | App (g, xs) => App (f g, List.map f xs)
        | Prim (p, t, xs) => Prim (p, ty t, List.map f xs)
        | Tuple xs => Tuple (List.map f xs)
        | Select (i, a) => Select (i, f a)
        | Con (tag, t, a) => Con (tag, ty t, f a)
        | Decon (tag, a) => Decon (tag, f a)
        | ConTag a => ConTag (f a)
        | MkExn (c, a) => MkExn (f c, f a)
        | ExnCon a => ExnCon (f a)
        | ExnArg (t, a) => ExnArg (ty t, f a)
        | SetGlobal (g, a) => SetGlobal (g, f a)
        | _ => r
      fun fundef ({name, tyvars, params, result, body} : fundef) =
        {name = name, tyvars = tyvars, params = List.map (fn (x, t) => (x, ty t)) params, result = ty result,
         body = exp body}
      and exp e =
        case e of
          Let (x, (tvs, t), r, b) => Let (x, (tvs, ty t), rhs r, exp b)
        | Fun (fs, b) => Fun (List.map fundef fs, exp b)
        | Join (j, ps, body, sc) => Join (j, List.map (fn (x, t) => (x, ty t)) ps, exp body, exp sc)
        | Jump (j, xs) => Jump (j, List.map f xs)
        | If (c, t, e) => If (f c, exp t, exp e)
        | Handle (a, x, h) => Handle (exp a, x, exp h)
        | Raise a => Raise (f a)
        | Return r => Return (rhs r)
        | Mark (sp, a) => Mark (sp, exp a)
    in exp e end

  (* The body of a function called once where it is made, in place of the
     call, is at the types of the call: its type variables are those types. *)
  fun substTypes (s : Ty.ty IntMap.map) (e : exp) : exp =
    if IntMap.isEmpty s then e
    else
      let
        val ty = Ty.subst s
        fun atom a =
          case a of
            Var (x, ts) => Var (x, List.map ty ts)
          | Global (g, ts) => Global (g, List.map ty ts)
          | Const (c, t) => Const (c, ty t)
          | Con0 (tag, t) => Con0 (tag, ty t)
          | Unit => Unit
      in mapExp (atom, ty) e end

  (* e with the variable x, which abstracts over no type, replaced by b. *)
  fun substVar (x : var, b : atom) (e : exp) : exp =
    mapExp (fn a as Var (y, []) => if y = x then b else a | a => a, fn t => t) e

  fun freshStamp () = Elaborate.freshStamp ()

  (* A round: e simplified in env, with the census taken before. *)
  fun simp (c : census, env : env, e : exp) : exp =
    case e of
      Let (x, s as (tvs, t), r, body) =>
        let val r = known (env, substRhs (env, r))
        in
          case r of
            Atom a =>
              if null tvs andalso spend () then (IntTable.insert (#subst env, x, a); simp (c, env, body))
              else Let (x, s, r, simp (c, env, body))
          | _ =>
              if uses (c, x) = 0 andalso removable r andalso spend () then simp (c, env, body)
              else
                (case r of
                   Tuple _ => IntTable.insert (#known env, x, Made r)
                 | Con _ => IntTable.insert (#known env, x, Made r)
                 | MkExn _ => IntTable.insert (#known env, x, Made r)
                 | _ => ();
                 Let (x, s, r, simp (c, env, body)))
        end
    | Fun (fs, body) =>
        if List.all (fn f => uses (c, #name f) = 0) fs andalso spend () then simp (c, env, body)
        else
          (case (fs, etaOf fs, callOnce (c, fs, body)) of
             ([f], SOME a, _) =>
               if spend () then (IntTable.insert (#subst env, #name f, substAtom (env, a)); simp (c, env, body))
               else keepFun (c, env, fs, body)
           | ([f], NONE, true) =>
               (case inlineCall (c, env, f, body) of
                  SOME e => simp (census e, env, e)
                | NONE => keepFun (c, env, fs, body))
           | _ => keepFun (c, env, fs, body))
    | Join (j, ps, jbody, scope) =>
        (case knownBool (j, ps, jbody, scope) of
           SOME e => simp (census e, env, e)
         | NONE => simpJoin (c, env, j, ps, jbody, scope))
    | Jump (j, xs) => Jump (j, List.map (fn a => substAtom (env, a)) xs)
    | If (cond, t, f) =>
        (case substAtom (env, cond) of
           Con0 (1, _) => if spend () then simp (c, env, t) else If (Con0 (1, Ty.bool), simp (c, env, t), simp (c, env, f))
         | Con0 (0, _) => if spend () then simp (c, env, f) else If (Con0 (0, Ty.bool), simp (c, env, t), simp (c, env, f))
         | a => If (a, simp (c, env, t), simp (c, env, f)))
    | Handle (a, x, h) =>
        if raisesHere a andalso spend () then
          let
            val jh = freshStamp ()
            val y = freshStamp ()
            val e = Join (jh, [(x, Ty.exn)], h, Handle (raisesTo jh a, y, Jump (jh, [Var (y, [])])))
          in simp (census e, env, e) end
        else Handle (simp (c, env, a), x, simp (c, env, h))
    | Raise a => Raise (substAtom (env, a))
    | Return r => Return (known (env, substRhs (env, r)))
    | Mark (sp, a) => Mark (sp, simp (c, env, a))

  and simpJoin (c, env, j, ps, jbody, scope) =
        if jumps (c, j) = 0 andalso spend () then simp (c, env, scope)
        else
          (case (if jumps (c, j) = 1 then placeJump (j, ps, jbody, scope) else NONE) of
             SOME e => if spend () then simp (c, env, e) else Join (j, ps, simp (c, env, jbody), simp (c, env, scope))
           | NONE => Join (j, ps, simp (c, env, jbody), simp (c, env, scope)))

  and keepFun (c, env, fs, body) =
    Fun (List.map (fn {name, tyvars, params, result, body = b} =>
                     {name = name, tyvars = tyvars, params = params, result = result, body = simp (c, env, b)}) fs,
         simp (c, env, body))

  (* The one function of fs, where it abstracts over no type variables and
     its body only calls another function with its parameter: that
     function, which is an atom, so to use it for this one changes nothing
     but that a call is saved. *)
  and etaOf (fs : fundef list) : atom option =
    let
      fun tail (Return r) = SOME r
        | tail (Mark (_, e)) = tail e
        | tail _ = NONE
    in
      case fs of
        [{name, tyvars = [], params = [(x, _)], body, ...}] =>
          (case tail body of
             SOME (App (g, [Var (y, [])])) =>
               (case g of
                  Var (h, _) => if y = x andalso h <> name andalso h <> x then SOME g else NONE
                | Global _ => if y = x then SOME g else NONE
                | _ => NONE)
           | _ => NONE)
      | _ => NONE
    end

  (* Whether the one function of fs is used once, by a call in body, where
     it is made -- not from inside a function of body, whose place would
     then be another's. *)
  and callOnce (c : census, fs : fundef list, body : exp) : bool =
    case fs of
      [f] => uses (c, #name f) = 1 andalso not (usesItself f) andalso calledHere (#name f, body)
    | _ => false

  and usesItself (f : fundef) : bool = uses (census (#body f), #name f) > 0

  (* The call of f in body: in body's own code, not a nested function's. *)
  and calledHere (f : int, e : exp) : bool =
    case e of
      Let (_, _, App (Var (g, _), [_]), b) => g = f orelse calledHere (f, b)
    | Let (_, _, _, b) => calledHere (f, b)
    | Fun (_, b) => calledHere (f, b)
    | Join (_, _, body, s) => calledHere (f, body) orelse calledHere (f, s)
    | If (_, t, e) => calledHere (f, t) orelse calledHere (f, e)
    | Handle (a, _, h) => calledHere (f, a) orelse calledHere (f, h)
    | Return (App (Var (g, _), [_])) => g = f
    | Mark (_, a) => calledHere (f, a)
    | _ => false

  (* The function f put where body calls it once: a call whose value goes
     on (Let) becomes a join point for what follows, which each return of f
     jumps to; a call in tail position becomes f's body. What is put in
     place has join points and variables the census of the round does not
     know of, so it is simplified after a census of its own -- which is
     whole: nothing it binds is used outside it. *)
  and inlineCall (c : census, env : env, f : fundef, body : exp) : exp option =
    let
      val param = case #params f of [(p, _)] => p | _ => bug "a function of other than one parameter"
      fun instance ts =
        ListPair.foldl (fn (a, t, s) => IntMap.insert (s, a, t)) IntMap.empty (#tyvars f, ts)
      fun paramTy ts = Ty.subst (instance ts) (#2 (hd (#params f)))
      (* f's body, its returns to k *)
      fun returnsTo (e : exp, k : rhs -> exp) : exp =
        case e of
          Let (x, s, r, b) => Let (x, s, r, returnsTo (b, k))
        | Fun (fs, b) => Fun (fs, returnsTo (b, k))
        | Join (j, ps, jb, s) => Join (j, ps, returnsTo (jb, k), returnsTo (s, k))
        | If (a, t, e) => If (a, returnsTo (t, k), returnsTo (e, k))
        | Handle (a, x, h) => Handle (returnsTo (a, k), x, returnsTo (h, k))
        | Return r => k r
        | Mark (sp, a) => Mark (sp, returnsTo (a, k))
        | _ => e
      fun place (e : exp) : exp option =
        case e of
          Let (x, s as (_, t), App (Var (g, ts), [arg]), rest) =>
            if g = #name f then
              if not (spend ()) then NONE
              else
                let
                  val j = freshStamp ()
                  val b = substTypes (instance ts) (#body f)
                  fun give r = let val v = freshStamp () in Let (v, ([], t), r, Jump (j, [Var (v, [])])) end
                in
                  SOME (Join (j, [(x, t)], rest, Let (param, ([], paramTy ts), Atom arg,
                                                     returnsTo (b, fn (Atom a) => Jump (j, [a]) | r => give r))))
                end
            else Option.map (fn rest' => Let (x, s, App (Var (g, ts), [arg]), rest')) (place rest)
        | Let (x, s, r, rest) => Option.map (fn rest' => Let (x, s, r, rest')) (place rest)
        | Return (App (Var (g, ts), [arg])) =>
            if g = #name f andalso spend () then
              SOME (Let (param, ([], paramTy ts), Atom arg, substTypes (instance ts) (#body f)))
            else NONE
        | Fun (fs, b) => Option.map (fn b' => Fun (fs, b')) (place b)
        | Join (j, ps, jb, s) =>
            (case place jb of
               SOME jb' => SOME (Join (j, ps, jb', s))
             | NONE => Option.map (fn s' => Join (j, ps, jb, s')) (place s))
        | If (a, t, e) =>
            (case place t of
               SOME t' => SOME (If (a, t', e))
             | NONE => Option.map (fn e' => If (a, t, e')) (place e))
        | Handle (a, x, h) =>
            (case place a of
               SOME a' => SOME (Handle (a', x, h))
             | NONE => Option.map (fn h' => Handle (a, x, h')) (place h))
        | Mark (sp, a) => Option.map (fn a' => Mark (sp, a')) (place a)
        | _ => NONE
    in
      place body
    end

  (* A join point whose body tests its one parameter, where some jump gives
     it a constant: a join point for each branch, the parameter that
     branch's constant in it, and the jumps with a constant made jumps to
     theirs; the others still go through the test. What this makes is new
     to the round's census, so it is simplified after one of its own. *)
  and knownBool (j : label, ps : (var * Ty.ty) list, jbody : exp, scope : exp) : exp option =
    case (ps, jbody) of
      ([(x, _)], If (Var (x', []), t, f)) =>
        if x = x' andalso jumpsWith (j, scope) andalso spend () then
          let
            val jt = freshStamp ()
            val jf = freshStamp ()
            fun redirect e =
              case e of
                Jump (j', [Con0 (tag, _)]) => if j' = j then Jump (if tag = 1 then jt else jf, []) else e
              | Let (y, s, r, b) => Let (y, s, r, redirect b)
              | Fun (fs, b) => Fun (fs, redirect b)
              | Join (k, qs, kb, s) => Join (k, qs, redirect kb, redirect s)
              | If (a, t, f) => If (a, redirect t, redirect f)
              | Handle (a, y, h) => Handle (redirect a, y, redirect h)
              | Mark (sp, a) => Mark (sp, redirect a)
              | _ => e
          in
            SOME (Join (jt, [], substVar (x, boolAtom true) t,
                        Join (jf, [], substVar (x, boolAtom false) f,
                              Join (j, ps, If (Var (x, []), Jump (jt, []), Jump (jf, [])), redirect scope))))
          end
        else NONE
    | _ => NONE

  (* Whether a jump in e gives j a constant. *)
  and jumpsWith (j : label, e : exp) : bool =
    case e of
      Jump (j', [Con0 _]) => j' = j
    | Let (_, _, _, b) => jumpsWith (j, b)
    | Fun (_, b) => jumpsWith (j, b)
    | Join (_, _, kb, s) => jumpsWith (j, kb) orelse jumpsWith (j, s)
    | If (_, t, f) => jumpsWith (j, t) orelse jumpsWith (j, f)
    | Handle (a, _, h) => jumpsWith (j, a) orelse jumpsWith (j, h)
    | Mark (_, a) => jumpsWith (j, a)
    | _ => false

  (* Whether a handler's region e raises in its own code: not in a function
     made there, nor in the region of a handler inside it -- though in that
     handler's code, which runs in e's region. *)
  and raisesHere (e : exp) : bool =
    case e of
      Raise _ => true
    | Let (_, _, _, b) => raisesHere b
    | Fun (_, b) => raisesHere b
    | Join (_, _, jb, s) => raisesHere jb orelse raisesHere s
    | If (_, t, f) => raisesHere t orelse raisesHere f
    | Handle (_, _, h) => raisesHere h
    | Mark (_, a) => raisesHere a
    | _ => false

  (* e with each raise raisesHere finds a jump to jh. *)
  and raisesTo (jh : label) (e : exp) : exp =
    case e of
      Raise a => Jump (jh, [a])
    | Let (x, s, r, b) => Let (x, s, r, raisesTo jh b)
    | Fun (fs, b) => Fun (fs, raisesTo jh b)
    | Join (j, ps, jb, s) => Join (j, ps, raisesTo jh jb, raisesTo jh s)
    | If (a, t, f) => If (a, raisesTo jh t, raisesTo jh f)
    | Handle (a, x, h) => Handle (a, x, raisesTo jh h)
    | Mark (sp, a) => Mark (sp, raisesTo jh a)
    | _ => e

  (* A join point jumped to once: its body where the jump is, the
     parameters bound to the arguments -- but not into the body of a
     handler's region, which would catch what the join point's body raises
     where the jump left the region first. *)
  and placeJump (j : label, ps : (var * Ty.ty) list, jbody : exp, scope : exp) : exp option =
    let
      fun go e : exp option =
        case e of
          Jump (j', xs) =>
            if j' = j then SOME (ListPair.foldr (fn ((x, t), a, b) => Let (x, ([], t), Atom a, b)) jbody (ps, xs))
            else NONE
        | Let (x, s, r, b) => Option.map (fn b' => Let (x, s, r, b')) (go b)
        | Fun (fs, b) => Option.map (fn b' => Fun (fs, b')) (go b)
        | Join (j', ps', jb, s) =>
            (case go jb of
               SOME jb' => SOME (Join (j', ps', jb', s))
             | NONE => Option.map (fn s' => Join (j', ps', jb, s')) (go s))
        | If (a, t, f) =>
            (case go t of
               SOME t' => SOME (If (a, t', f))
             | NONE => Option.map (fn f' => If (a, t, f')) (go f))
        | Handle (a, x, h) => Option.map (fn h' => Handle (a, x, h')) (go h)
        | Mark (sp, a) => Option.map (fn a' => Mark (sp, a')) (go a)
        | _ => NONE
    in go scope end

  (* The rounds over an expression of the top level: three at most, and
     none after one that rewrote nothing. *)
  fun rounds (n : int, e : exp) : exp =
    if n = 0 then e
    else
      let
        val c = census e
        val () = changed := false
        val e' = simp (c, {subst = IntTable.table 64, known = IntTable.table 64}, e)
      in
        if !changed then rounds (n - 1, e') else e'
      end

  fun program (p : program) : program =
    let
      fun fundef ({name, tyvars, params, result, body} : fundef) =
        {name = name, tyvars = tyvars, params = params, result = result, body = rounds (3, body)}
    in
      List.map (fn Val (g, s, e) => Val (g, s, rounds (3, e))
                 | Funs fs => Funs (List.map fundef fs)
                 | Do (gs, e) => Do (gs, rounds (3, e))) p
    end
end
