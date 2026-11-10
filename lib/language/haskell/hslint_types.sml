(* The types of HsLint's second inference (the haskell98 roadmap's M16 and
   D54): the kinds, types, predicates, qualified types and schemes of
   Typing Haskell in Haskell (Jones 1999, sections 3 to 8), with its
   unifier and its matching. They are HsLint's own and share nothing with
   the checker's (D54: only the renamer is shared).

   One change of representation from the paper: its substitution is a
   value threaded through the inference monad, and here it is held in the
   type variables, each a cell that unification links to a type, so that
   the paper's `apply s t` is `zonk t`. A variable also records the module
   whose restricted binding left it monomorphic, for Rule 2 over a cycle
   of modules (D30). *)
structure HsLintTypes =
struct
  (* ---- kinds (3) ---- *)

  datatype kind = Star | KFun of kind * kind

  fun showKind Star = "*"
    | showKind (KFun (a as KFun _, b)) = "(" ^ showKind a ^ ") -> " ^ showKind b
    | showKind (KFun (a, b)) = showKind a ^ " -> " ^ showKind b

  (* ---- types (4) ---- *)

  (* an entity's name as the renamer gives it: the identity of the module
     that defines it, or "" for a local or the built-in syntax *)
  type id = HsAst.qname

  fun idEq (a : id, b : id) = #qual a = #qual b andalso #name a = #name b
  fun idKey ({qual, name} : id) = qual ^ " " ^ name

  datatype ty =
      TVar of tyvar
    | TCon of tycon
    | TAp of ty * ty
    | TGen of int
  and tyvar = TV of {id : int, kind : kind, link : ty option ref, owner : string ref}
  withtype tycon = {id : id, kind : kind}

  (* a breach of the rules, where and what; HsLint reports the first *)
  exception Refuse of HsSource.span * string

  (* a failure of unification, which the caller words *)
  exception Unify of string

  val counter = ref 0

  fun newTVar k =
    (counter := !counter + 1; TVar (TV {id = !counter, kind = k, link = ref NONE, owner = ref ""}))

  fun tvId (TV {id, ...}) = id
  fun tvKind (TV {kind, ...}) = kind
  fun tvEq (a, b) = tvId a = tvId b

  (* the type a variable stands for, through its links *)
  fun prune (t as TVar (TV {link, ...})) =
        (case !link of
           SOME t' => let val r = prune t' in link := SOME r; r end
         | NONE => t)
    | prune t = t

  (* the type with every bound variable replaced by its binding: `apply` *)
  fun zonk t =
    case prune t of
      TAp (a, b) => TAp (zonk a, zonk b)
    | t' => t'

  fun kindOf t =
    case prune t of
      TVar v => tvKind v
    | TCon {kind, ...} => kind
    | TAp (f, _) => (case kindOf f of KFun (_, k) => k | Star => raise Unify "a type of kind * applied")
    | TGen _ => raise Unify "a generic variable has no kind of its own"

  (* the built-in type constructors, with the special syntax's names *)
  fun builtin name = {qual = "", name = name} : id
  val tArrow = TCon {id = builtin "(->)", kind = KFun (Star, KFun (Star, Star))}
  val tList = TCon {id = builtin "[]", kind = KFun (Star, Star)}
  val tUnit = TCon {id = builtin "()", kind = Star}
  fun tupleName n = "(" ^ CharVector.tabulate (n - 1, fn _ => #",") ^ ")"
  fun tTuple n =
    let fun k 0 = Star | k i = KFun (Star, k (i - 1))
    in TCon {id = builtin (tupleName n), kind = k n} end
  fun fn_ (a, b) = TAp (TAp (tArrow, a), b)
  fun list t = TAp (tList, t)
  fun tuple ts = List.foldl (fn (t, f) => TAp (f, t)) (tTuple (length ts)) ts
  fun fnMany (args, r) = List.foldr fn_ r args

  (* the head of an application and its arguments *)
  fun spine t =
    let
      fun go (t, args) = case prune t of TAp (f, a) => go (f, a :: args) | h => (h, args)
    in
      go (t, [])
    end

  (* ---- free variables, in the order they appear (tv) ---- *)

  fun tvsAcc (t, acc) =
    case prune t of
      TVar v => if List.exists (fn w => tvEq (v, w)) acc then acc else v :: acc
    | TAp (a, b) => tvsAcc (b, tvsAcc (a, acc))
    | _ => acc

  fun tvs t = List.rev (tvsAcc (t, []))
  fun tvsList ts = List.rev (List.foldl tvsAcc [] ts)

  fun occurs (v, t) =
    case prune t of
      TVar w => tvEq (v, w)
    | TAp (a, b) => occurs (v, a) orelse occurs (v, b)
    | _ => false

  (* ---- unification (6): the most general unifier, held in the cells ---- *)

  (* The module whose code is inferred, where Rule 2 closes at the end of
     each module of a cycle (D30's default, `--cycle-default=module`): a
     monomorphic variable of another module's binding may not be fixed by
     its code. "" where Rule 2 closes at the end of the cycle. *)
  val ruleTwo = ref ""

  fun ownerOf (TV {owner, ...}) = !owner

  fun foreign v = !ruleTwo <> "" andalso ownerOf v <> "" andalso ownerOf v <> !ruleTwo

  fun varBind (v as TV {link, kind, ...}, t) =
    case prune t of
      TVar (w as TV {link = wl, ...}) =>
        if tvEq (v, w) then ()
        else if kind <> tvKind w then raise Unify "kinds do not match"
        (* a monomorphic variable of a binding stays the representative *)
        else if ownerOf v <> "" andalso ownerOf w = "" then wl := SOME (TVar v)
        else link := SOME t
    | t' =>
        if occurs (v, t') then raise Unify "occurs check: an infinite type"
        else if kindOf t' <> kind then raise Unify "kinds do not match"
        else if foreign v then
          raise Unify ("the monomorphic type of a binding of the module " ^ ownerOf v ^ " is fixed by a use in " ^ !ruleTwo ^
                       ": in a cycle Rule 2 holds each module's to the module alone (D30)")
        else link := SOME t'

  fun unify (a, b) =
    case (prune a, prune b) of
      (TVar v, t) => varBind (v, t)
    | (t, TVar v) => varBind (v, t)
    | (TAp (f, x), TAp (g, y)) => (unify (f, g); unify (x, y))
    | (TCon c, TCon d) => if idEq (#id c, #id d) then () else raise Unify "types do not match"
    | _ => raise Unify "types do not match"

  (* whether two types are the same, their variables included *)
  fun same (a, b) =
    case (prune a, prune b) of
      (TVar v, TVar w) => tvEq (v, w)
    | (TCon c, TCon d) => idEq (#id c, #id d)
    | (TAp (f, x), TAp (g, y)) => same (f, g) andalso same (x, y)
    | (TGen i, TGen j) => i = j
    | _ => false

  (* `matchGen (slots, template, t)`: the template's generic variables
     bound in `slots` so that it is `t`, one way (match) *)
  fun matchGen (slots : ty option array, template, t) =
    case (template, prune t) of
      (TGen i, t') =>
        (case Array.sub (slots, i) of
           NONE => (Array.update (slots, i, SOME t'); true)
         | SOME u => same (u, t'))
    | (TCon c, TCon d) => idEq (#id c, #id d)
    | (TAp (f, x), TAp (g, y)) => matchGen (slots, f, g) andalso matchGen (slots, x, y)
    | _ => false

  (* the template with its generic variables replaced: `inst` *)
  fun inst (ts : ty vector) t =
    case t of
      TGen i => Vector.sub (ts, i)
    | TAp (a, b) => TAp (inst ts a, inst ts b)
    | _ => t

  (* ---- predicates and qualified types (7) ---- *)

  datatype pred = IsIn of id * ty

  fun predTvs ps = List.rev (List.foldl (fn (IsIn (_, t), acc) => tvsAcc (t, acc)) [] ps)
  fun predEq (IsIn (c, t), IsIn (d, u)) = idEq (c, d) andalso same (t, u)
  fun zonkPred (IsIn (c, t)) = IsIn (c, zonk t)
  fun instPred ts (IsIn (c, t)) = IsIn (c, inst ts t)

  (* a qualified type and a scheme (8): `Forall (kinds, (ps, t))`, its
     generic variables numbered in the order `quantify` met them *)
  datatype scheme = Forall of kind list * (pred list * ty)

  fun toScheme t = Forall ([], ([], t))

  (* `quantify (vs, (ps, t))`: the scheme over the variables of `vs`, in
     the order they appear in the predicates and then the type *)
  fun quantify (vs : tyvar list, (ps, t)) =
    let
      val order = List.rev (tvsAcc (t, List.rev (predTvs ps)))
      val vs' = List.filter (fn v => List.exists (fn w => tvEq (v, w)) vs) order
      fun index (v, i, []) = NONE
        | index (v, i, w :: ws) = if tvEq (v, w) then SOME i else index (v, i + 1, ws)
      fun gen t =
        case prune t of
          TVar v => (case index (v, 0, vs') of SOME i => TGen i | NONE => TVar v)
        | TAp (a, b) => TAp (gen a, gen b)
        | t' => t'
    in
      Forall (List.map tvKind vs', (List.map (fn IsIn (c, t) => IsIn (c, gen t)) ps, gen t))
    end

  fun freshInst (Forall (ks, (ps, t))) =
    let val ts = Vector.fromList (List.map newTVar ks)
    in (List.map (instPred ts) ps, inst ts t) end

  (* the variables of a scheme's type that are not generic *)
  fun schemeTvs (Forall (_, (ps, t))) = List.rev (tvsAcc (t, List.rev (predTvs ps)))

  (* whether two schemes are one, up to their generic variables' names *)
  fun schemeEq (Forall (ks, (ps, t)), Forall (ks', (ps', t'))) =
    ks = ks' andalso same (t, t') andalso length ps = length ps'
    andalso List.all (fn p => List.exists (fn q => predEq (p, q)) ps') ps
    andalso List.all (fn p => List.exists (fn q => predEq (p, q)) ps) ps'

  (* ---- the text of a type, for messages and dumps ---- *)

  fun genName i =
    let val c = str (Char.chr (Char.ord #"a" + i mod 26))
    in if i < 26 then c else c ^ Int.toString (i div 26) end

  (* The names of a message's free type variables: t1, t2, ... in the
     order the message meets them, so that its text does not depend on how
     many variables the inference made before. *)
  val names : int list ref = ref []

  fun varName id =
    let
      fun find (_, []) = NONE
        | find (i, x :: xs) = if x = id then SOME i else find (i + 1, xs)
    in
      case find (1, !names) of
        SOME i => "t" ^ Int.toString i
      | NONE => (names := !names @ [id]; "t" ^ Int.toString (length (!names)))
    end

  (* `message f` is `f ()` with the names of its type variables fresh *)
  fun message f = (names := []; let val m = f () in names := []; m end)

  fun showTyAt (prec0, t) =
    let
      fun paren (b, s) = if b then "(" ^ s ^ ")" else s
      fun head h =
        case h of
          TVar (TV {id, ...}) => varName id
        | TCon {id = {name, ...}, ...} => name
        | TGen i => genName i
        | TAp _ => "?"
      (* 0: an arrow's result or the top; 1: an arrow's argument; 2: an
         application's argument *)
      fun go (prec, t) =
        case spine t of
          (TCon {id = {qual = "", name = "(->)"}, ...}, [a, b]) => paren (prec > 0, go (1, a) ^ " -> " ^ go (0, b))
        | (TCon {id = {qual = "", name = "[]"}, ...}, [a]) => "[" ^ go (0, a) ^ "]"
        | (h as TCon {id = {qual = "", name}, ...}, args as _ :: _) =>
            if String.isPrefix "(," name andalso length args = size name - 1 then
              "(" ^ String.concatWith ", " (List.map (fn a => go (0, a)) args) ^ ")"
            else apply (prec, h, args)
        | (h, []) => head h
        | (h, args) => apply (prec, h, args)
      and apply (prec, h, args) = paren (prec > 1, String.concatWith " " (head h :: List.map (fn a => go (2, a)) args))
    in
      go (prec0, t)
    end

  fun showTy t = showTyAt (0, t)

  fun showPred (IsIn ({name, ...}, t)) = name ^ " " ^ showTyAt (2, t)

  (* predicates in a canonical order: by the text *)
  fun sortStrings xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if String.<= (x, y) then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] xs
    end

  fun showScheme (Forall (ks, (ps, t))) =
    let
      val qs = sortStrings (List.map showPred ps)
      val ctx = case qs of [] => "" | [q] => q ^ " => " | _ => "(" ^ String.concatWith ", " qs ^ ") => "
    in
      ctx ^ showTy t
    end
end
