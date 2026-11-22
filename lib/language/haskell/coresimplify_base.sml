(* What the Core simplifier's passes share (coresimplify_sig.sml; the
   haskell98 roadmap's M23): fresh names, the count of each kind of rewrite
   and the question asked before each, the program's types and values as
   tables, the size of an expression, which expressions are values, and
   the occurrences of each variable.

   A pass keeps every binder of a declaration distinct: the first pass
   makes them so (`distinct`), and every copy of an expression the passes
   make, an inlined body or a specialised one, is given fresh names. So a
   variable substituted never meets a binder of its own name, and a fact
   about a variable holds wherever its name is seen. *)
structure CoreSimplifyBase =
struct
  open Core

  (* ---- Fresh names ---- *)

  val counter = ref 0

  (* x without the suffix ~N that `fresh` gave it *)
  fun baseOf (x : string) : string =
    let
      val n = String.size x
      fun scan i =
        if i < 0 then x
        else
          let val c = String.sub (x, i)
          in
            if Char.isDigit c then scan (i - 1)
            else if c = #"~" andalso i < n - 1 andalso i > 0 then String.substring (x, 0, i)
            else x
          end
    in scan (n - 1) end

  (* a name that no binder has yet, made from x *)
  fun fresh (x : string) : string = (counter := !counter + 1; baseOf x ^ "~" ^ Int.toString (!counter))

  (* ---- Rewrites, counted and asked for ---- *)

  (* the question asked before each rewrite (Pass.spend, so that --fuel
     can stop the rewriting) *)
  val spendRef : (unit -> bool) ref = ref (fn () => true)

  (* each kind of rewrite with how many were made *)
  val counts : (string * int ref) list ref = ref []

  fun count (what : string) : unit =
    case List.find (fn (w, _) => w = what) (!counts) of
      SOME (_, r) => r := !r + 1
    | NONE => counts := !counts @ [(what, ref 1)]

  (* whether a rewrite of the kind `what` is made: asked, and counted *)
  fun tick (what : string) : bool = if !spendRef () then (count what; true) else false

  (* ---- The program's types and values ---- *)

  type datatypes = {datas : ((string * kind) list * (string * ty list) list) CoreMap.map,
                    cons : string CoreMap.map,
                    newtypes : ((string * kind) list * string * ty) CoreMap.map,
                    dicts : bool CoreMap.map}

  (* the data types and newtypes of p and the built-in ones; a dictionary's
     data type is one of one constructor named %dict:..., as desugaring
     makes a class's (HS_DS_ENV) *)
  fun datatypes (p : program) : datatypes =
    let
      fun isDict cs = case cs of [(c, _)] => String.isPrefix "%dict:" c | _ => false
      fun add (d, acc as {datas, cons, newtypes, dicts}) =
        case d of
          Data (t, ps, cs) =>
            {datas = CoreMap.insert (datas, t, (ps, cs)),
             cons = List.foldl (fn ((c, _), m) => CoreMap.insert (m, c, t)) cons cs,
             newtypes = newtypes, dicts = if isDict cs then CoreMap.insert (dicts, t, true) else dicts}
        | Newtype (t, ps, c, f) => {datas = datas, cons = cons, newtypes = CoreMap.insert (newtypes, t, (ps, c, f)), dicts = dicts}
        | _ => acc
    in
      List.foldl add {datas = CoreMap.empty, cons = CoreMap.empty, newtypes = CoreMap.empty, dicts = CoreMap.empty}
        (builtinData @ p)
    end

  (* whether t is a type of dictionaries *)
  fun isDictTy (dt : datatypes) (t : ty) : bool =
    case spine (stripEval t) of
      (TCon c, _) => CoreMap.member (#dicts dt, c)
    | _ => false

  (* the types of the fields of constructor c at the types tys *)
  fun fieldTys (dt : datatypes) (c : string, tys : ty list) : ty list option =
    case CoreMap.find (#cons dt, c) of
      SOME t =>
        (case CoreMap.find (#datas dt, t) of
           SOME (ps, cs) =>
             (case List.find (fn (k, _) => k = c) cs of
                SOME (_, fs) =>
                  if length ps = length tys then
                    SOME (List.map (fn f => substTy (ListPair.map (fn ((a, _), u) => (a, u)) (ps, tys), f)) fs)
                  else NONE
              | NONE => NONE)
         | NONE => NONE)
    | NONE => NONE

  (* whether t is unlifted, the state token or an unboxed tuple *)
  fun isUnliftedTy (t : ty) : bool =
    case stripEval t of
      TCon "World" => true
    | TUTuple _ => true
    | _ => false

  (* t unfolded once, where a newtype is at its head *)
  fun unfold (dt : datatypes) (t : ty) : ty option =
    case spine (stripEval t) of
      (TCon c, args) =>
        (case CoreMap.find (#newtypes dt, c) of
           SOME (ps, _, f) =>
             if length ps = length args then SOME (substTy (ListPair.map (fn ((a, _), u) => (a, u)) (ps, args), f))
             else NONE
         | NONE => NONE)
    | _ => NONE

  (* ---- Expressions ---- *)

  (* the size of e, counted to `limit` and no further: a node each *)
  fun sizeUpTo (limit : int) (e : exp) : int =
    let
      fun go (e, n) =
        if n > limit then n
        else
          case e of
            Atom _ => n + 1
          | App (f, args) => go (f, n + 1 + length args)
          | Lam (bs, b) => go (b, n + 1)
          | Let (_, _, r, b) => go (b, go (r, n + 1))
          | LetRec (bs, b) => go (b, List.foldl (fn ((_, _, r), n) => go (r, n)) (n + 1) bs)
          | Case (s, _, alts) => List.foldl (fn (a, n) => go (altRhs a, n + 1)) (go (s, n + 1)) alts
          | Con (_, _, xs) => n + 1 + length xs
          | Prim (_, _, xs) => n + 1 + length xs
          | UTuple xs => n + 1 + length xs
          | Cast (e, _) => go (e, n)
    in go (e, 0) end

  and altRhs (AltCon (_, _, e)) = e
    | altRhs (AltLit (_, e)) = e
    | altRhs (AltUTuple (_, e)) = e
    | altRhs (AltDefault e) = e

  (* the leading lets of e, outermost first, and what they are around *)
  datatype binding = NonRec of string * ty * exp | Rec of (string * ty * exp) list

  fun peelLets (e : exp) : binding list * exp =
    let
      fun go (Let (x, t, r, b), acc) = go (b, NonRec (x, t, r) :: acc)
        | go (LetRec (bs, b), acc) = go (b, Rec bs :: acc)
        | go (e, acc) = (List.rev acc, e)
    in go (e, []) end

  fun wrapLets (bs : binding list, e : exp) : exp =
    List.foldr (fn (NonRec (x, t, r), e) => Let (x, t, r, e) | (Rec bs, e) => LetRec (bs, e)) e bs

  (* whether e is a value whose making does no work, which a let binds as
     it is and which may be copied where work may not: a lambda, a
     constructor, an atom, or one of those cast *)
  fun isValue (e : exp) : bool =
    case e of
      Lam (bs, b) => List.exists (fn ValBinder _ => true | _ => false) bs orelse isValue b
    | Con _ => true
    | Atom _ => true
    | UTuple _ => false
    | Cast (e, _) => isValue e
    | _ => false

  (* whether e is an atom, or an atom cast: a copy of it costs nothing *)
  fun isTrivial (e : exp) : bool =
    case e of
      Atom _ => true
    | Cast (e, _) => isTrivial e
    | _ => false

  (* the value binders of a lambda's binders *)
  fun valueArity (bs : binder list) : int = List.length (List.filter (fn ValBinder _ => true | _ => false) bs)

  (* whether e raises: a raise, or a function the desugaring raises
     through, applied *)
  fun isBottom (e : exp) : bool =
    case e of
      Prim (p, _, _) => p = "raise" orelse p = "raise_io"
    | App (Atom (Var f), _) => String.isPrefix "%raise:" f orelse f = "primError" orelse f = "haskell98:Prelude.error"
    | Let (_, _, _, b) => isBottom b
    | Case (_, _, [AltDefault b]) => isBottom b
    | _ => false

  (* ---- Occurrences ---- *)

  (* how a variable occurs: how many times, whether once inside a lambda
     that its binding is outside of, whether once as an argument, where an
     atom must stand, and whether once as a component of an unboxed tuple,
     whose type is its atoms': Core to Mid takes a cast's expression at its
     own type, so such a component keeps whether it is evaluated *)
  type occ = {n : int, lam : bool, arg : bool, tup : bool}

  (* the occurrences of every variable p binds, local and global, each
     binder with none until a use is seen: a lambda of a value binder is a
     place that may run many times, and a type lambda is not *)
  fun occurrences (p : program) : occ CoreMap.map =
    let
      val occs = ref (CoreMap.empty : occ CoreMap.map)
      val depths = ref (CoreMap.empty : int CoreMap.map)
      fun bind (x, d) =
        if x = "_" then ()
        else (depths := CoreMap.insert (!depths, x, d);
              if CoreMap.member (!occs, x) then () else occs := CoreMap.insert (!occs, x, {n = 0, lam = false, arg = false, tup = false}))
      fun use (x, d, arg, tup) =
        let
          val inLam = case CoreMap.find (!depths, x) of SOME b => d > b | NONE => d > 0
          val o' = case CoreMap.find (!occs, x) of
                     SOME {n, lam, arg = a, tup = t} => {n = n + 1, lam = lam orelse inLam, arg = a orelse arg, tup = t orelse tup}
                   | NONE => {n = 1, lam = inLam, arg = arg, tup = tup}
        in occs := CoreMap.insert (!occs, x, o') end
      fun atom d (Var x) = use (x, d, true, false)
        | atom _ (Lit _) = ()
      fun component d (Var x) = use (x, d, true, true)
        | component _ (Lit _) = ()
      fun exp d e =
        case e of
          Atom (Var x) => use (x, d, false, false)
        | Atom (Lit _) => ()
        | App (f, args) => (exp d f; List.app (fn ValArg a => atom d a | TyArg _ => ()) args)
        | Lam (bs, b) =>
            let val d' = if valueArity bs > 0 then d + 1 else d
            in List.app (fn ValBinder (x, _) => bind (x, d') | TyBinder _ => ()) bs; exp d' b end
        | Let (x, _, r, b) => (bind (x, d); exp d r; exp d b)
        | LetRec (bs, b) => (List.app (fn (x, _, _) => bind (x, d)) bs; List.app (fn (_, _, r) => exp d r) bs; exp d b)
        | Case (s, b, alts) =>
            (exp d s; bind (b, d);
             List.app (fn AltCon (_, xs, r) => (List.app (fn x => bind (x, d)) xs; exp d r)
                        | AltUTuple (xs, r) => (List.app (fn x => bind (x, d)) xs; exp d r)
                        | AltLit (_, r) => exp d r
                        | AltDefault r => exp d r) alts)
        | Con (_, _, xs) => List.app (atom d) xs
        | Prim (_, _, xs) => List.app (atom d) xs
        | UTuple xs => List.app (component d) xs
        | Cast (e, _) => exp d e
      fun decl (Val (x, _, e)) = (bind (x, 0); exp 0 e)
        | decl (Import (x, _)) = bind (x, 0)
        | decl _ = ()
    in List.app decl p; !occs end

  (* how x occurs, by the table of `occurrences`: a name it does not hold,
     one a pass made since, may occur anywhere *)
  fun occOf (occs : occ CoreMap.map, x : string) : occ =
    getOpt (CoreMap.find (occs, x), {n = 2, lam = true, arg = true, tup = true})

  (* ---- Binders made distinct ---- *)

  (* p with every binder distinct from every other of the program, and
     from every name of its top level: a binder whose name was seen already
     is given a fresh one. A type variable a type binds (a forall's) is the
     type's own, and is left as it is *)
  fun distinct (p : program) : program =
    let
      val seen = ref (CoreMap.empty : bool CoreMap.map)
      fun see x = seen := CoreMap.insert (!seen, x, true)
      (* the name of a binder, and the renaming in force under it *)
      fun name (ren, x) =
        if x = "_" then (x, ren)
        else if CoreMap.member (!seen, x) then let val y = fresh x in see y; (y, CoreMap.insert (ren, x, y)) end
        else (see x; (x, ren))
      fun tyOf (tren, t) = case tren of [] => t | _ => substTy (tren, t)
      fun atom ren (Var x) = (case CoreMap.find (ren, x) of SOME y => Var y | NONE => Var x)
        | atom _ a = a
      fun tyName (tren, a) =
        if CoreMap.member (!seen, a) then let val b = fresh a in see b; (b, (a, TVar b) :: tren) end
        else (see a; (a, tren))
      fun exp (ren, tren) e =
        case e of
          Atom a => Atom (atom ren a)
        | App (f, args) =>
            App (exp (ren, tren) f, List.map (fn ValArg a => ValArg (atom ren a) | TyArg t => TyArg (tyOf (tren, t))) args)
        | Lam (bs, b) =>
            let
              fun go ([], ren, tren, acc) = Lam (List.rev acc, exp (ren, tren) b)
                | go (TyBinder (a, k) :: rest, ren, tren, acc) =
                    let val (a', tren') = tyName (tren, a) in go (rest, ren, tren', TyBinder (a', k) :: acc) end
                | go (ValBinder (x, t) :: rest, ren, tren, acc) =
                    let val (x', ren') = name (ren, x) in go (rest, ren', tren, ValBinder (x', tyOf (tren, t)) :: acc) end
            in go (bs, ren, tren, []) end
        | Let (x, t, r, b) =>
            let val r' = exp (ren, tren) r
                val (x', ren') = name (ren, x)
            in Let (x', tyOf (tren, t), r', exp (ren', tren) b) end
        | LetRec (bs, b) =>
            let
              val (names, ren') = List.foldl (fn ((x, _, _), (acc, ren)) => let val (y, ren) = name (ren, x) in (y :: acc, ren) end)
                                             ([], ren) bs
              val names = List.rev names
            in
              LetRec (ListPair.map (fn (y, (_, t, r)) => (y, tyOf (tren, t), exp (ren', tren) r)) (names, bs), exp (ren', tren) b)
            end
        | Case (s, b, alts) =>
            let
              val s' = exp (ren, tren) s
              val (b', ren') = name (ren, b)
              fun names (xs, ren) =
                let val (ys, ren) = List.foldl (fn (x, (acc, ren)) => let val (y, ren) = name (ren, x) in (y :: acc, ren) end) ([], ren) xs
                in (List.rev ys, ren) end
              fun alt (AltCon (c, xs, r)) = let val (ys, ren'') = names (xs, ren') in AltCon (c, ys, exp (ren'', tren) r) end
                | alt (AltUTuple (xs, r)) = let val (ys, ren'') = names (xs, ren') in AltUTuple (ys, exp (ren'', tren) r) end
                | alt (AltLit (l, r)) = AltLit (l, exp (ren', tren) r)
                | alt (AltDefault r) = AltDefault (exp (ren', tren) r)
            in Case (s', b', List.map alt alts) end
        | Con (c, tys, xs) => Con (c, List.map (fn t => tyOf (tren, t)) tys, List.map (atom ren) xs)
        | Prim (q, tys, xs) => Prim (q, List.map (fn t => tyOf (tren, t)) tys, List.map (atom ren) xs)
        | UTuple xs => UTuple (List.map (atom ren) xs)
        | Cast (e, t) => Cast (exp (ren, tren) e, tyOf (tren, t))
      (* the top level's names are seen first: no local takes one *)
      val () = List.app (fn Val (x, _, _) => see x | Import (x, _) => see x | _ => ()) p
      fun decl (Val (x, t, e)) = Val (x, t, exp (CoreMap.empty, []) e)
        | decl d = d
    in List.map decl p end
end
