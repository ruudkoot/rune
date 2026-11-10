(* The types of the intermediate representations (docs/ir.md): immutable,
   made from the elaborator's after elaboration has finished, when every
   variable of a type is either generic -- one of a scheme's -- or known to
   stand for nothing more (Gen and Var). A record is a tuple of its fields in
   the order of their labels, and a type made abstract by an opaque
   signature is what it stands for, so that the representation says what a
   value is and not what a signature lets a program see.

   A type is hash-consed (performance M4, D4 A): each node is made once,
   through a table, and has a number of its own, so that two types are equal
   where their numbers are, and a walk over a type can be memoised on the
   numbers of its nodes -- a type the elaborator shares, of 2^n nodes as a
   tree, is n nodes here, and is walked as n (MLton's regression
   exponential.sml; Shao, League and Monnier, ICFP 1998). A node is seen
   through `view` and made by the functions named after its constructors:
   gen, var, con, tuple, arrow, exnCon, app and forall.

   Two forms are for a front end whose types say more than SML's (D4 of
   docs/plans/language/haskell98.md), which the elaborator never makes: a
   type variable applied to types (App: Haskell's `m a`), whose variable
   stands for a type name not yet given its last arguments (a Con with
   fewer arguments than its datatype's parameters: `maybe`, of `'a maybe`);
   and a forall in a field (Forall: a dictionary's polymorphic method),
   which binds its own generic variables. A forall is the same type as
   another that differs from it only in the names of the variables it
   binds, so that two foralls are equal where they are the same node or
   are so (equal), though only the same node is one.

   The elaborator fills the tables below as it goes, so that a type can be
   found for what the translation meets: the scheme of every variable, the
   constructors of every datatype, the argument of every exception, and what
   each opaque type stands for. *)
structure Ty =
struct
  structure Node :>
  sig
    type ty
    datatype view =
        Gen of int                        (* a generic variable of a scheme, by the elaborator's id *)
      | Var of int                        (* a variable no type was found for: equal to itself only *)
      | Con of int * string * ty list     (* a type name, by stamp, and its arguments *)
      | Tuple of ty list                  (* a record or tuple; unit is Tuple [] *)
      | Arrow of ty * ty
      | ExnCon                            (* an exception constructor *)
      | App of ty * ty list               (* a type variable, Gen or Var, applied to types *)
      | Forall of int list * ty           (* a field's polymorphic type: the generic variables it binds, its body *)
    (* the node of each view, made where there is none yet; app of a type
       name is the type name given more arguments, of an application the
       application given more, and of no arguments its head; forall of no
       variable is its body *)
    val gen : int -> ty
    val var : int -> ty
    val con : int * string * ty list -> ty
    val tuple : ty list -> ty
    val arrow : ty * ty -> ty
    val exnCon : ty
    val app : ty * ty list -> ty
    val forall : int list * ty -> ty
    val view : ty -> view
    (* whether a type has a forall in it, and an application: what no type
       of SML's has, so that a walk that asks the other forms alone can
       know it need not look *)
    val hasForall : ty -> bool
    val hasApp : ty -> bool
    (* a node's number: two nodes are the same type where theirs are *)
    val id : ty -> int
    (* the number of nodes of a type as a tree, to sizeLimit *)
    val size : ty -> int
    val sizeLimit : int
    (* the generic variables of a type, each once, in the order a walk from
       the left meets them *)
    val gens : ty -> int list
  end =
  struct
    (* its number, its hash, its size, its generic variables, what it has
       of the forms of other front ends (a forall, 1, and an application,
       2, in a word's bits) and its view, the third to fifth worked out as
       it is made *)
    datatype ty = T of int * int * int * int list * int * view
    and view =
        Gen of int
      | Var of int
      | Con of int * string * ty list
      | Tuple of ty list
      | Arrow of ty * ty
      | ExnCon
      | App of ty * ty list
      | Forall of int list * ty

    fun id (T (i, _, _, _, _, _)) = i
    fun hashOf (T (_, h, _, _, _, _)) = h
    fun size (T (_, _, n, _, _, _)) = n
    fun gens (T (_, _, _, g, _, _)) = g
    fun forms (T (_, _, _, _, f, _)) = f
    fun view (T (_, _, _, _, _, v)) = v
    fun hasForall t = forms t mod 2 = 1
    fun hasApp t = forms t div 2 mod 2 = 1
    (* the forms of the parts, joined: bits, as a number below 4 *)
    fun join (a, b) = if a = b then a else if a = 0 then b else if b = 0 then a else 3
    fun formsOf ts = List.foldl (fn (t, f) => join (forms t, f)) 0 ts
    val sizeLimit = 1000000

    (* the nodes by a hash of their view -- its constructor, its numbers and
       its parts' numbers, in words, which wrap round -- in buckets, no
       more nodes than buckets *)
    val buckets : ty list array ref = ref (Array.array (1024, []))
    val () = CompilerState.refRoot ("Ty.Node.buckets", buckets, CompilerState.copyArray)
    val count = ref 0
    val () = CompilerState.cellRoot ("Ty.Node.count", count)
    val next = ref 0
    val () = CompilerState.cellRoot ("Ty.Node.next", next)

    (* a hash: the constructor's number, then the numbers of the view and
       of its parts, in words, which wrap round, to 30 bits *)
    fun mix (h : word, x : int) : word = h * 0w31 + Word.fromInt x
    fun ids (h, []) = h
      | ids (h, t :: ts) = ids (mix (h, id t), ts)
    fun final (h : word) : int = Word.toInt (Word.andb (h, 0wx3FFFFFFF))

    (* the same parts; a type name's name is not its identity, only its
       stamp *)
    fun sameIds (x :: xs, y :: ys) = id x = id y andalso sameIds (xs, ys)
      | sameIds ([], []) = true
      | sameIds _ = false

    fun add (t, n) = Int.min (sizeLimit, n + size t)
    fun sizes ts = List.foldl add 1 ts

    (* the variables of acc, then those of t that are not among them *)
    fun union (t, acc) =
      case (gens t, acc) of
        ([], _) => acc
      | (xs, []) => xs
      | (xs, _) => List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else acc @ [x]) acc xs
    fun gensOf ts = List.foldl union [] ts

    fun grow () =
      let
        val old = !buckets
        val new = Array.array (2 * Array.length old, [])
        fun put t = let val i = hashOf t mod Array.length new in Array.update (new, i, t :: Array.sub (new, i)) end
      in
        Array.app (List.app put) old; buckets := new
      end

    fun bucket h = let val a = !buckets in Array.sub (a, h mod Array.length a) end

    (* a node not made yet, of its hash, its size, its variables, its
       forms and its view *)
    fun new (h, n, g, f, v) =
      let
        val a = !buckets
        val i = h mod Array.length a
        val t = T (!next, h, n, g, f, v)
      in
        next := !next + 1;
        Array.update (a, i, t :: Array.sub (a, i));
        count := !count + 1;
        if !count > Array.length a then grow () else ();
        t
      end

    (* each constructor's: the node in the bucket of its hash that has the
       view, or a new one; a view made only for a new node *)
    fun gen x =
      let
        val h = final (mix (0w1, x))
        fun find [] = new (h, 1, [x], 0, Gen x)
          | find ((t as T (_, h', _, _, _, v)) :: rest) =
              if h <> h' then find rest else case v of Gen x' => if x = x' then t else find rest | _ => find rest
      in find (bucket h) end

    fun var x =
      let
        val h = final (mix (0w2, x))
        fun find [] = new (h, 1, [], 0, Var x)
          | find ((t as T (_, h', _, _, _, v)) :: rest) =
              if h <> h' then find rest else case v of Var x' => if x = x' then t else find rest | _ => find rest
      in find (bucket h) end

    fun con (s, name, ts) =
      let
        val h = final (ids (mix (0w3, s), ts))
        fun find [] = new (h, sizes ts, gensOf ts, formsOf ts, Con (s, name, ts))
          | find ((t as T (_, h', _, _, _, v)) :: rest) =
              if h <> h' then find rest
              else case v of Con (s', _, ts') => if s = s' andalso sameIds (ts, ts') then t else find rest | _ => find rest
      in find (bucket h) end

    fun tuple ts =
      let
        val h = final (ids (0w4, ts))
        fun find [] = new (h, sizes ts, gensOf ts, formsOf ts, Tuple ts)
          | find ((t as T (_, h', _, _, _, v)) :: rest) =
              if h <> h' then find rest else case v of Tuple ts' => if sameIds (ts, ts') then t else find rest | _ => find rest
      in find (bucket h) end

    fun arrow (a, b) =
      let
        val (i, j) = (id a, id b)
        val h = final (mix (mix (0w5, i), j))
        fun find [] = new (h, add (b, add (a, 1)), union (b, gens a), join (forms a, forms b), Arrow (a, b))
          | find ((t as T (_, h', _, _, _, v)) :: rest) =
              if h <> h' then find rest
              else case v of Arrow (a', b') => if i = id a' andalso j = id b' then t else find rest | _ => find rest
      in find (bucket h) end

    val exnCon = new (final 0w6, 1, [], 0, ExnCon)

    (* its arguments' variables, then its head's, as the text writes it *)
    fun app (h, ts) =
      case (view h, ts) of
        (_, []) => h
      | (Con (s, name, xs), _) => con (s, name, xs @ ts)
      | (App (h', xs), _) => app (h', xs @ ts)
      | _ =>
          let
            val hh = final (ids (mix (0w7, id h), ts))
            fun find [] = new (hh, add (h, sizes ts), union (h, gensOf ts), join (2, join (forms h, formsOf ts)), App (h, ts))
              | find ((t as T (_, h', _, _, _, v)) :: rest) =
                  if hh <> h' then find rest
                  else case v of App (g, ts') => if id g = id h andalso sameIds (ts, ts') then t else find rest | _ => find rest
          in find (bucket hh) end

    (* its body's variables but those it binds *)
    fun forall (vs, b) =
      case vs of
        [] => b
      | _ =>
          let
            val h = final (mix (List.foldl (fn (v, h) => mix (h, v)) 0w8 vs, id b))
            fun find [] = new (h, add (b, 1), List.filter (fn g => not (List.exists (fn v => v = g) vs)) (gens b),
                               join (1, forms b), Forall (vs, b))
              | find ((t as T (_, h', _, _, _, v)) :: rest) =
                  if h <> h' then find rest
                  else case v of Forall (ws, c) => if ws = vs andalso id c = id b then t else find rest | _ => find rest
          in find (bucket h) end
  end
  open Node

  (* A walk of a type of at most smallType nodes as a tree is one of the
     tree, without a table: as quick, and making nothing *)
  val smallType = 64

  (* ---- the tables ---- *)

  (* the type, or scheme, each variable was bound with, by its stamp *)
  val binders : Types.ty IntTable.table = IntTable.table 8192
  val () = CompilerState.tableRoot ("Ty.binders", binders)
  (* the argument of each exception, by its stamp *)
  val exnArgs : Types.ty option IntTable.table = IntTable.table 256
  val () = CompilerState.tableRoot ("Ty.exnArgs", exnArgs)
  (* the argument of each copy a pass made of an exception declared in a
     function (Expand, Simplify, Lift, MidCanon: copyExn), by the copy's
     stamp, as a type here, with the copy's types: so that MidLint checks
     MkExn in the copies as in the original (linting roadmap, M4); and of
     one whose declaration a pass put at other types where it was
     (Simplify's body of a function called once: retypeExn), which stands
     for the elaborator's *)
  val exnCopies : ty option IntTable.table = IntTable.table 64
  val () = CompilerState.tableRoot ("Ty.exnCopies", exnCopies)
  (* each datatype, by the stamp of its type name: the ids of its parameters,
     and each constructor's tag, name and argument, as the elaborator gave it
     or, for one Mid's text declares (MidText), as it is *)
  datatype argTy = FromElab of Types.ty | Direct of ty
  type datatypeInfo = {params : int list, cons : (int * string * argTy option) list}
  val datatypes : datatypeInfo IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Ty.datatypes", datatypes)
  (* what each type made abstract by an opaque signature stands for, by the
     stamp of its fresh name *)
  val realizations : Types.tyfcn IntTable.table = IntTable.table 256
  val () = CompilerState.tableRoot ("Ty.realizations", realizations)

  (* A datatype declared in a function may name the function's type
     variables (`fun 'a f ... = let datatype t = T of 'a ...`): an instance
     of the function -- inlined, specialised -- gives them other types, which
     a type of t must say for its constructors' arguments to agree. So each
     such variable is a parameter of t after its own, which every type made
     of t (fromTypes) gives as itself: the generic variables its
     constructors name that are not its parameters, and those of the
     datatypes they name. Worked out once the elaborator has given every
     datatype (extrasOf); in most programs no datatype has any. *)
  datatype extras = Unknown | NoExtras | Extras of int list IntMap.map
  val extras = ref Unknown
  val () = CompilerState.cellRoot ("Ty.extras", extras)

  fun bindVar (stamp : int, t : Types.ty) = IntTable.insert (binders, stamp, t)
  (* the names and types of the variables bound, kept where the REPL
     debugs (`-g`; the REPL roadmap's M12), which shows them: binders loses
     a unit's once it is compiled (UnitBasis.undo) *)
  val keepNames = ref false
  val () = CompilerState.cellRoot ("Ty.keepNames", keepNames)
  val names : (string * Types.ty) IntTable.table = IntTable.table 64
  val () = CompilerState.tableRoot ("Ty.names", names)
  fun nameVar (stamp : int, name : string, t : Types.ty) =
    if !keepNames then IntTable.insert (names, stamp, (name, t)) else ()
  fun bindExn (stamp : int, arg : Types.ty option) = IntTable.insert (exnArgs, stamp, arg)
  fun bindDatatype (stamp : int, {params, cons} : {params : int list, cons : (int * string * Types.ty option) list}) =
    (extras := Unknown;
     datatypes := IntMap.insert (!datatypes, stamp,
                                 {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map FromElab a)) cons}))
  fun bindDatatypeDirect (stamp : int, {params, cons} : {params : int list, cons : (int * string * ty option) list}) =
    (extras := Unknown;
     datatypes := IntMap.insert (!datatypes, stamp,
                                 {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map Direct a)) cons}))
  fun bindRealization (stamp : int, fcn : Types.tyfcn) = IntTable.insert (realizations, stamp, fcn)

  (* bool and list, which no declaration makes: list's tags as
     Types.tagNames numbers them (bindBuiltins) *)
  val listParam = Types.freshTvar (Types.genericLevel, Types.KPlain, false)
  fun bindBuiltins () =
    let
      val a = listParam
      val aid = case a of Types.TVar (ref (Types.Unbound {id, ...})) => id | _ => 0
      val cons = [(Types.nilTag (), "nil", NONE), (Types.consTag (), "::", SOME (Types.tupleTy [a, Types.listTy a]))]
    in
      bindDatatype (#stamp Types.boolTycon, {params = [], cons = [(0, "false", NONE), (1, "true", NONE)]});
      bindDatatype (#stamp Types.listTycon,
                    {params = [aid], cons = if Types.nilTag () = 0 then cons else List.rev cons})
    end
  val () = bindBuiltins ()

  (* ---- from the elaborator's types ---- *)

  (* the generic variables an elaborator's type names, and the datatypes,
     added to acc *)
  fun scan (t : Types.ty, acc as (gens, stamps) : unit IntMap.map * unit IntMap.map) =
    case Types.prune t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        if level = Types.genericLevel then (IntMap.insert (gens, id, ()), stamps) else acc
    | Types.TVar (ref (Types.Bound t)) => scan (t, acc)
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => scan (Types.TCon (c', args), acc)
         | SOME (Types.TAbbrev (params, body)) => scan (Types.substitute (params, args, body), acc)
         | NONE => List.foldl scan (gens, IntMap.insert (stamps, #stamp c, ())) args)
    | Types.TRecord fields => List.foldl (fn ((_, t), acc) => scan (t, acc)) acc fields
    | Types.TArrow (a, b) => scan (b, scan (a, acc))

  (* whether an elaborator's type names a generic variable not in params *)
  fun namesOther (params : int list) (t : Types.ty) : bool =
    case Types.prune t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        level = Types.genericLevel andalso not (List.exists (fn p => p = id) params)
    | Types.TVar (ref (Types.Bound t)) => namesOther params t
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => namesOther params (Types.TCon (c', args))
         | SOME (Types.TAbbrev (ps, body)) => namesOther params (Types.substitute (ps, args, body))
         | NONE => List.exists (namesOther params) args)
    | Types.TRecord fields => List.exists (namesOther params o #2) fields
    | Types.TArrow (a, b) => namesOther params a orelse namesOther params b

  (* each datatype's extra parameters (extras), where it has some *)
  fun workOutExtras () : int list IntMap.map =
    let
      (* each datatype of the elaborator's: the variables its
         constructors name that are not its parameters, and the
         datatypes they name *)
      val direct =
        IntMap.map (fn {params, cons} =>
                      let
                        val (gens, stamps) =
                          List.foldl (fn ((_, _, SOME (FromElab t)), acc) => scan (t, acc) | (_, acc) => acc)
                                     (IntMap.empty, IntMap.empty) cons
                      in
                        (IntMap.filteri (fn (g, ()) => not (List.exists (fn p => p = g) params)) gens,
                         IntMap.listKeys stamps)
                      end)
                   (!datatypes)
      (* and those of the datatypes they name, until no more come *)
      fun round m =
        let
          val m' =
            IntMap.mapi (fn (s, gens) =>
                           case IntMap.find (direct, s) of
                             SOME (_, named) =>
                               List.foldl (fn (n, g) =>
                                             case IntMap.find (m, n) of
                                               SOME g' => IntMap.unionWith #1 (g, g')
                                             | NONE => g)
                                          gens named
                           | NONE => gens)
                        m
        in
          if IntMap.foldl (fn (g, n) => n + IntMap.numItems g) 0 m'
             = IntMap.foldl (fn (g, n) => n + IntMap.numItems g) 0 m
          then m else round m'
        end
    in
      IntMap.map (fn gs => IntMap.listKeys gs)
                 (IntMap.filteri (fn (_, gs) => not (IntMap.isEmpty gs)) (round (IntMap.map #1 direct)))
    end

  (* the table, worked out only where some datatype names a variable not
     among its parameters *)
  fun computeExtras () : extras =
    let
      val some =
        IntMap.foldl (fn ({params, cons}, any) =>
                        any orelse List.exists (fn (_, _, SOME (FromElab t)) => namesOther params t | _ => false) cons)
                     false (!datatypes)
      val e = if not some then NoExtras
              else let val m = workOutExtras () in if IntMap.isEmpty m then NoExtras else Extras m end
    in
      extras := e; e
    end

  fun extrasOf (stamp : int) : int list =
    case (case !extras of Unknown => computeExtras () | e => e) of
      NoExtras => []
    | Extras m => (case IntMap.find (m, stamp) of SOME l => l | NONE => [])
    | Unknown => []

  (* An elaborator's type as a type here. A type the elaborator shares is a
     variable's cell bound to it, each named as often as the type is. A type
     of at most smallType nodes is converted as a tree (tree); a bigger one
     has each cell of more than smallType nodes converted once, for a
     conversion (memoised: an association list, cells having an identity
     and no order), so that a type of 2^n nodes as a tree is converted in
     some n * smallType steps, and so is its budget of type work spent
     (Types.prune). *)

  (* a node, its parts converted by go *)
  fun convert (go : Types.ty -> ty, t : Types.ty) : ty =
    case t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        if level = Types.genericLevel then gen id else var id
    | Types.TVar (ref (Types.Bound t)) => go t
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => convert (go, Types.TCon (c', args))
         | SOME (Types.TAbbrev (params, body)) => go (Types.substitute (params, args, body))
         | NONE =>
             (case !extras of
                NoExtras => con (#stamp c, #name c, List.map go args)
              | _ =>
                  (case extrasOf (#stamp c) of
                     [] => con (#stamp c, #name c, List.map go args)
                   | extra => con (#stamp c, #name c, List.map go args @ List.map gen extra))))
    | Types.TRecord fields => tuple (List.map (go o #2) fields)
    | Types.TArrow (a, b) => arrow (go a, go b)

  exception Big
  val treeSteps = ref 0
  val () = CompilerState.cellRoot ("Ty.treeSteps", treeSteps)
  fun tree (t : Types.ty) : ty =
    let val n = !treeSteps + 1
    in
      if n > smallType then raise Big
      else (treeSteps := n; convert (tree, Types.prune t))
    end

  fun memoised (t : Types.ty) : ty =
    let
      val memo : (Types.tvar ref * ty) list ref = ref []
      fun go t =
        case t of
          Types.TVar (r as ref (Types.Bound t')) =>
            (case List.find (fn (r', _) => r' = r) (!memo) of
               SOME (_, x) => x
             | NONE => let val x = go t' in if size x > smallType then memo := (r, x) :: !memo else (); x end)
        | _ => convert (go, Types.prune t)
    in go t end

  fun fromTypes (t : Types.ty) : ty =
    (treeSteps := 0; tree t) handle Big => memoised t

  fun argOf (FromElab t) = fromTypes t
    | argOf (Direct t) = t

  (* A datatype's parameters, its extra ones after its own, and its
     constructors' arguments as types. *)
  fun paramsOf (stamp : int, params : int list) =
    case !extras of
      NoExtras => params
    | _ => (case extrasOf stamp of [] => params | extra => params @ extra)
  (* (functors-units.md, D4) a constructor's object
     seen whatever its datatype, through which a functor's body builds and
     takes apart a constructor whose layout its parameter leaves open, by
     the descriptor its argument gives (Translate): `flatN` has a
     constructor of each tag below flatTags, whose argument is N units, a
     tuple of them laid out flat for N >= 2, and one boxed for N = 1. A
     type name of the basis, below the elaborator's first (Types), which no
     declaration makes and no table holds *)
  val flatTags = 256
  val maxFlat = 8
  fun flatStamp (n : int) : int = 20 + n
  fun flatOf (stamp : int) : int option = if stamp > 20 andalso stamp <= 20 + maxFlat then SOME (stamp - 20) else NONE
  fun flatArg (n : int) : ty = tuple (if n = 1 then [] else List.tabulate (n, fn _ => tuple []))
  fun flat (n : int) : ty = con (flatStamp n, "flat" ^ Int.toString n, [])

  fun datatypeOf (stamp : int) : {params : int list, cons : (int * string * ty option) list} option =
    case flatOf stamp of
      SOME n => SOME {params = [], cons = List.tabulate (flatTags, fn t => (t, "C" ^ Int.toString t, SOME (flatArg n)))}
    | NONE =>
    case IntMap.find (!datatypes, stamp) of
      NONE => NONE
    | SOME {params, cons} =>
        SOME {params = paramsOf (stamp, params), cons = List.map (fn (t, n, a) => (t, n, Option.map argOf a)) cons}

  (* ---- layouts (functors-units.md, D5) ---- *)

  (* The number of fields of each constructor of a datatype, by tag: SOME n
     for one whose declared argument is a tuple of n >= 2 -- one object of
     those fields -- and NONE for one that boxes its argument or has none
     (Rep, docs/ir.md). Worked out from the declared arguments, or fixed
     where the datatype was made, for an instance an application's
     summary names (pinned): the body compiled once makes it so, whatever
     the instance's types say. *)
  val pinned : (int * int option) list IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Ty.pinned", pinned)
  fun pinLayout (stamp : int, l : (int * int option) list) = pinned := IntMap.insert (!pinned, stamp, l)
  (* the datatypes a functor's parameter specifies with a constructor whose
     layout the argument gives (D4), by stamp: what no function made of the
     datatype's layout may take apart (Simplify's equality) *)
  val openTypes : unit IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Ty.openTypes", openTypes)
  fun markOpen (stamp : int) = openTypes := IntMap.insert (!openTypes, stamp, ())
  fun isOpen (stamp : int) : bool = IntMap.member (!openTypes, stamp)
  fun declaredLayout (stamp : int) : (int * int option) list =
    case datatypeOf stamp of
      SOME {cons, ...} =>
        List.map (fn (tag, _, SOME a) =>
                       (case view a of
                          Tuple xs => (tag, if List.length xs >= 2 then SOME (List.length xs) else NONE)
                        | _ => (tag, NONE))
                   | (tag, _, NONE) => (tag, NONE)) cons
    | NONE => []
  fun layoutOf (stamp : int) : (int * int option) list =
    case IntMap.find (!pinned, stamp) of
      SOME l => l
    | NONE => declaredLayout stamp

  (* The same, from the elaborator's types as they are, without making
     types of them (fromTypes), which works out every datatype's extra
     parameters again after a datatype is entered: what the elaborator
     asks of a datatype between entering others (an application's
     instances) *)
  fun shapeOf (t : Types.ty) : int option =
    case Types.prune t of
      Types.TRecord fields => if List.length fields >= 2 then SOME (List.length fields) else NONE
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => shapeOf (Types.TCon (c', args))
         | SOME (Types.TAbbrev (params, body)) => shapeOf (Types.substitute (params, args, body))
         | NONE => NONE)
    | _ => NONE
  fun elabLayout (stamp : int) : (int * int option) list =
    case IntMap.find (!pinned, stamp) of
      SOME l => l
    | NONE =>
        case flatOf stamp of
          SOME _ => declaredLayout stamp
        | NONE =>
            case IntMap.find (!datatypes, stamp) of
              SOME {cons, ...} =>
                List.map (fn (tag, _, SOME (FromElab a)) => (tag, shapeOf a)
                           | (tag, _, SOME (Direct a)) =>
                               (tag, case view a of Tuple xs => if List.length xs >= 2 then SOME (List.length xs) else NONE
                                                  | _ => NONE)
                           | (tag, _, NONE) => (tag, NONE)) cons
            | NONE => []

  (* ---- the types the translation makes ---- *)

  val int = con (#stamp Types.intTycon, "int", [])
  val int64 = con (#stamp Types.int64Tycon, #name Types.int64Tycon, [])
  val word64 = con (#stamp Types.word64Tycon, #name Types.word64Tycon, [])
  val bool = con (#stamp Types.boolTycon, "bool", [])
  val string = con (#stamp Types.stringTycon, "string", [])
  val exn = con (#stamp Types.exnTycon, "exn", [])
  val unit = tuple []
  fun list t = con (#stamp Types.listTycon, "list", [t])
  fun refTy t = con (#stamp Types.refTycon, "ref", [t])

  (* ---- comparing and instantiating ---- *)

  (* The same type: the same node, or two with foralls in them that differ
     only in the names of the variables those bind. *)
  fun alpha (a : ty, b : ty) : bool =
    let
      (* each forall's variables around, of a and of b, by their places *)
      fun go (ra, rb, n, a, b) =
        if n = 0 andalso not (hasForall a) andalso not (hasForall b) then id a = id b
        else
          case (view a, view b) of
            (Gen x, Gen y) =>
              (case (IntMap.find (ra, x), IntMap.find (rb, y)) of
                 (SOME i, SOME j) => i = j
               | (NONE, NONE) => x = y
               | _ => false)
          | (Var x, Var y) => x = y
          | (Con (s, _, xs), Con (s', _, ys)) => s = s' andalso all (ra, rb, n, xs, ys)
          | (Tuple xs, Tuple ys) => all (ra, rb, n, xs, ys)
          | (Arrow (x1, x2), Arrow (y1, y2)) => go (ra, rb, n, x1, y1) andalso go (ra, rb, n, x2, y2)
          | (ExnCon, ExnCon) => true
          | (App (g, xs), App (h, ys)) => go (ra, rb, n, g, h) andalso all (ra, rb, n, xs, ys)
          | (Forall (vs, c), Forall (ws, d)) =>
              List.length vs = List.length ws
              andalso let
                        fun places (us, k, r) = List.foldl (fn (u, (k, r)) => (k + 1, IntMap.insert (r, u, k))) (k, r) us
                        val (n', ra') = places (vs, n, ra)
                        val (_, rb') = places (ws, n, rb)
                      in go (ra', rb', n', c, d) end
          | _ => false
      and all (ra, rb, n, xs, ys) =
        List.length xs = List.length ys andalso ListPair.all (fn (x, y) => go (ra, rb, n, x, y)) (xs, ys)
    in go (IntMap.empty, IntMap.empty, 0, a, b) end
  fun equal (a : ty, b : ty) : bool = id a = id b orelse (hasForall a andalso hasForall b andalso alpha (a, b))

  (* Generic variables no type of a program names, for a forall's own made
     anew where a substitution would capture them (subst) *)
  val nextBound = ref 0
  val () = CompilerState.cellRoot ("Ty.nextBound", nextBound)
  fun freshBound () = (nextBound := !nextBound - 1; !nextBound - 1000000000)

  (* The generic variables of a scheme made the types an instance gives
     them: SOME the substitution where the instance is one, NONE where it is
     not. A pair of nodes is matched once. *)
  fun match (scheme : ty, inst : ty) : ty IntMap.map option =
    let
      exception No
      (* the pairs met, by the scheme's node, for a scheme too big to walk
         as a tree *)
      val seen : int list IntTable.table option =
        if size scheme <= smallType then NONE else SOME (IntTable.table 64)
      fun go (x, y, s) =
        case seen of
          NONE => step (x, y, s)
        | SOME seen =>
            let val (i, j) = (id x, id y)
            in
              if List.exists (fn k => k = j) (getOpt (IntTable.find (seen, i), [])) then s
              else let val s = step (x, y, s) in IntTable.update (seen, i, fn l => j :: getOpt (l, [])); s end
            end
      and step (x, y, s) =
        case (view x, view y) of
          (Gen g, _) =>
            (case IntMap.find (s, g) of
               SOME t' => if equal (y, t') then s else raise No
             | NONE => IntMap.insert (s, g, y))
        | (Con (a, _, xs), Con (b, _, ys)) =>
            if a = b andalso List.length xs = List.length ys then ListPair.foldl (fn (x, y, s) => go (x, y, s)) s (xs, ys)
            else raise No
        | (Tuple xs, Tuple ys) =>
            if List.length xs = List.length ys then ListPair.foldl (fn (x, y, s) => go (x, y, s)) s (xs, ys)
            else raise No
        | (Arrow (x1, x2), Arrow (y1, y2)) => go (x2, y2, go (x1, y1, s))
        (* an application at a type name given at least as many arguments,
           or at another application: its variable the type name, or the
           application, given those before its own *)
        | (App (h, xs), Con (a, n, ys)) => apps (h, xs, fn k => con (a, n, k), ys, s)
        | (App (h, xs), App (g, ys)) => apps (h, xs, fn k => app (g, k), ys, s)
        | (Forall (vs, b), Forall (ws, c)) =>
            if List.length vs <> List.length ws then raise No
            else
              (* their variables made the same new ones, which match only
                 themselves *)
              let
                val fresh = List.map (fn _ => freshBound ()) vs
                fun rename us = ListPair.foldl (fn (u, f, m) => IntMap.insert (m, u, gen f)) IntMap.empty (us, fresh)
                val s' = go (subst (rename vs) b, subst (rename ws) c, s)
                fun itself f = case IntMap.find (s', f) of SOME t => equal (t, gen f) | NONE => true
              in
                if List.all itself fresh then List.foldl (fn (f, m) => if IntMap.member (m, f) then IntMap.remove (m, f) else m) s' fresh
                else raise No
              end
        | _ => if equal (x, y) then s else raise No
      and apps (h, xs, head, ys, s) =
        let val k = List.length ys - List.length xs
        in
          if k < 0 then raise No
          else ListPair.foldl (fn (x, y, s) => go (x, y, s)) (go (h, head (List.take (ys, k)), s)) (xs, List.drop (ys, k))
        end
    in
      SOME (go (scheme, inst, IntMap.empty)) handle No => NONE
    end

  (* A type with its generic variables made what s says: each node once,
     and a node that names none of s's as it is. *)
  and subst (s : ty IntMap.map) (t : ty) : ty =
    if IntMap.isEmpty s then t
    else if size t <= smallType then
      let
        fun same (xs, ys) = ListPair.allEq (fn (x, y) => id x = id y) (xs, ys)
        fun tree t =
          case view t of
            Gen x => (case IntMap.find (s, x) of SOME t' => t' | NONE => t)
          | Con (a, n, xs) => let val ys = List.map tree xs in if same (xs, ys) then t else con (a, n, ys) end
          | Tuple xs => let val ys = List.map tree xs in if same (xs, ys) then t else tuple ys end
          | Arrow (a, b) =>
              let val (a', b') = (tree a, tree b)
              in if id a = id a' andalso id b = id b' then t else arrow (a', b') end
          | App (h, xs) =>
              let val (h', ys) = (tree h, List.map tree xs)
              in if id h = id h' andalso same (xs, ys) then t else app (h', ys) end
          | Forall (vs, b) => under (s, vs, b)
          | Var _ => t
          | ExnCon => t
      in tree t end
    else
      let
        val done : ty IntTable.table = IntTable.table 64
        fun go t =
          if not (List.exists (fn g => IntMap.member (s, g)) (gens t)) then t
          else
            case IntTable.find (done, id t) of
              SOME u => u
            | NONE =>
                let
                  val u =
                    case view t of
                      Gen x => (case IntMap.find (s, x) of SOME t' => t' | NONE => t)
                    | Con (a, n, xs) => con (a, n, List.map go xs)
                    | Tuple xs => tuple (List.map go xs)
                    | Arrow (a, b) => arrow (go a, go b)
                    | App (h, xs) => app (go h, List.map go xs)
                    | Forall (vs, b) => under (s, vs, b)
                    | Var _ => t
                    | ExnCon => t
                in IntTable.insert (done, id t, u); u end
      in go t end
  (* A forall's body with s made of its free variables, those it binds
     made anew where a type s gives names one of them *)
  and under (s : ty IntMap.map, vs : int list, b : ty) : ty =
    let
      val s = List.foldl (fn (v, s) => if IntMap.member (s, v) then IntMap.remove (s, v) else s) s vs
      val given = List.mapPartial (fn g => IntMap.find (s, g)) (gens b)
    in
      if List.exists (fn v => List.exists (fn t => List.exists (fn g => g = v) (gens t)) given) vs then
        let
          val ws = List.map (fn _ => freshBound ()) vs
          val s = ListPair.foldl (fn (v, w, s) => IntMap.insert (s, v, gen w)) s (vs, ws)
        in forall (ws, subst s b) end
      else forall (vs, subst s b)
    end

  (* A forall's body at the types given for the variables it binds: what a
     polymorphic field is at an instance (MidLint) *)
  fun instantiate (t : ty, args : ty list) : ty option =
    case view t of
      Forall (vs, b) =>
        if List.length vs = List.length args then
          SOME (subst (ListPair.foldl (fn (v, a, s) => IntMap.insert (s, v, a)) IntMap.empty (vs, args)) b)
        else NONE
    | _ => NONE

  (* The argument of the constructor with a tag, of a datatype at the
     arguments given, where the datatype is one and it has that constructor:
     SOME NONE for a nullary one. *)
  fun conArg (stamp : int, args : ty list, tag : int) : ty option option =
    case flatOf stamp of
      SOME n => if tag >= 0 andalso tag < flatTags andalso List.null args then SOME (SOME (flatArg n)) else NONE
    | NONE =>
    case IntMap.find (!datatypes, stamp) of
      NONE => NONE
    | SOME {params, cons} =>
        (case List.find (fn (t, _, _) => t = tag) cons of
           NONE => NONE
         | SOME (_, _, arg) =>
             let val params = paramsOf (stamp, params)
             in
               if List.length params <> List.length args then NONE
               else
                 let
                   val s = ListPair.foldl (fn (p, a, s) => IntMap.insert (s, p, a)) IntMap.empty (params, args)
                 in
                   SOME (Option.map (subst s o argOf) arg)
                 end
             end)

  (* A type as text, a variable written as the functions given say, a type
     name as name says, and a part of it as abbrev says where it says (an
     abbreviation, MidText): the type itself is written out where expand. *)
  fun formatWith (gen : int -> string, var : int -> string, name : int * string -> string,
                  abbrev : ty -> string option) (expand : bool) (t : ty) : string =
    let
      fun go t = case abbrev t of SOME s => s | NONE => node t
      and node t =
        case view t of
          Gen x => gen x
        | Var x => var x
        | Con (s, n, []) => name (s, n)
        | Con (s, n, [a]) => atomic a ^ " " ^ name (s, n)
        | Con (s, n, xs) => "(" ^ String.concatWith ", " (List.map go xs) ^ ") " ^ name (s, n)
        | Tuple [] => "unit"
        | Tuple [x] => "{" ^ go x ^ "}"         (* a record of one field *)
        | Tuple xs => String.concatWith " * " (List.map atomic xs)
        | Arrow (a, b) => atomic a ^ " -> " ^ go b
        | ExnCon => "exncon"
        (* a variable applied as a type name is, after its arguments *)
        | App (h, [a]) => atomic a ^ " " ^ go h
        | App (h, xs) => "(" ^ String.concatWith ", " (List.map go xs) ^ ") " ^ go h
        | Forall (vs, b) => "(forall [" ^ String.concatWith " " (List.map gen vs) ^ "] " ^ go b ^ ")"
      and atomic t =
        case abbrev t of
          SOME s => s
        | NONE =>
            case view t of
              Tuple (_ :: _ :: _) => "(" ^ node t ^ ")"
            | Arrow _ => "(" ^ node t ^ ")"
            | _ => node t
    in if expand then node t else go t end

  (* A type of more than printLimit nodes as a tree is written by its size
     alone, so that a message or a dump of Lambda (whose text has no
     abbreviations, as MidText's has) stays of some size: a type of 2^n
     nodes as a tree is n nodes here, but not on paper *)
  val printLimit = 100000
  fun elided t =
    if size t <= printLimit then NONE
    else SOME ("<a type of " ^ (if size t >= sizeLimit then "a million nodes or more" else Int.toString (size t) ^ " nodes") ^ ">")

  fun formatNamed (gen : int -> string, var : int -> string, name : int * string -> string) (t : ty) : string =
    formatWith (gen, var, name, elided) false t

  fun format (gen : int -> string, var : int -> string) (t : ty) : string = formatNamed (gen, var, #2) t

  (* by the elaborator's ids, for messages *)
  val toString = format (fn x => "'a" ^ Int.toString x, fn x => "'_" ^ Int.toString x)

  (* The argument of the exception a stamp declares, where it is known: SOME
     NONE for one of no argument; NONE where the stamp is no exception's, or
     a copy's no pass registered *)
  fun exnArgOf (stamp : int) : ty option option =
    case IntTable.find (exnCopies, stamp) of
      SOME arg => SOME arg
    | NONE => Option.map (Option.map fromTypes) (IntTable.find (exnArgs, stamp))
  (* the copy y of the exception x, its argument's types made what f makes
     of them (a copy's substitution), registered where x's is known and a
     lint will look (from level 1: Pass.linting') *)
  fun copyExn (x : int, y : int, f : ty -> ty) : unit =
    if not (Pass.linting' 1) then ()
    else
      case exnArgOf x of
        SOME arg => IntTable.insert (exnCopies, y, Option.map f arg)
      | NONE => ()
  (* the exception x, declared where it was at the types f makes of its
     argument's *)
  fun retypeExn (x : int, f : ty -> ty) : unit = copyExn (x, x, f)

  (* A constant at its type: the digits of an Int64.int or a Word64.word are
     the 64-bit constant, which is another representation where int and word
     are the VM's 63 bits. *)
  fun constAt (c : Literal.const, t : ty) : Literal.const =
    case (c, view t) of
      (Literal.CInt i, Con (stamp, _, _)) => if stamp = #stamp Types.int64Tycon then Literal.CInt64 i else c
    | (Literal.CWord w, Con (stamp, _, _)) => if stamp = #stamp Types.word64Tycon then Literal.CWord64 w else c
    | _ => c
end
