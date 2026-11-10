(* The types of Haskell 98's checker (the haskell98 roadmap's M13, D31):
   kinds, types with unification variables, predicates and schemes, and
   first-order unification with levels.

   A type constructor is named by the key of its entity (`HsModules.key`),
   or is one of the built-in ones, named as the renamer leaves them: `()`,
   `[]`, `->`, and the tuples' `(,)`, `(,,)` and on. A unification
   variable is a cell, linked once it is solved; its level is the depth of
   the binding group that made it, so that generalisation takes the
   variables deeper than the group's level, and its home is the module
   whose code made it, which Rule 2 in a cycle reads (D30). A variable of a
   signature or of an instance head, fixed while it is checked, is rigid.

   Area: Languages *)
signature HS_TYPES =
sig
  (* A kind, with variables that kind inference solves. *)
  datatype kind = KStar | KFun of kind * kind | KVar of kvar ref
  (* A kind variable: unsolved, by its number, or linked to a kind. *)
  and kvar = KFree of int | KLink of kind

  (* `newKind ()` is a fresh kind variable. *)
  val newKind : unit -> kind

  (* `kindRepr k` follows the links of `k`'s variable, if it has one. *)
  val kindRepr : kind -> kind

  (* `defaultKind k` is `k` with every unsolved variable made `*`. *)
  val defaultKind : kind -> kind

  (* `showKind k` is `k` as the Report writes one. *)
  val showKind : kind -> string

  (* Two kinds that cannot be one. *)
  exception KindMismatch of kind * kind

  (* `unifyKind (a, b)` makes `a` and `b` one kind.

     Raises: `KindMismatch` where they cannot be. *)
  val unifyKind : kind * kind -> unit

  (* A rigid variable: a number for itself and its name as written. *)
  type rigid = {id : int, name : string}

  (* A type. `TGen i` is the `i`th variable a scheme binds. *)
  datatype ty =
      TCon of string
    | TAp of ty * ty
    | TMeta of meta ref
    | TGen of int
    | TRigid of rigid
  (* A unification variable: unsolved, with its number, its level and its
     home module, or linked to the type it was solved as. *)
  and meta =
      Free of {id : int, level : int, home : string}
    | Link of ty

  (* A predicate, `C t`: a class, by the key of its entity, and a type. *)
  type pred = {cls : string, ty : ty}

  (* A scheme: the number of variables it binds, its context and its type,
     over `TGen 0` to `TGen (vars - 1)`. *)
  type scheme = {vars : int, ctx : pred list, ty : ty}

  (* The unit's type constructor, `()`. *)
  val unitCon : string
  (* The list's type constructor, `[]`. *)
  val listCon : string
  (* The function's type constructor, `->`. *)
  val arrowCon : string
  (* `tupleCon n` is the type constructor of the tuples of `n` components. *)
  val tupleCon : int -> string

  (* `builtinKind name` is the kind of a built-in type constructor. *)
  val builtinKind : string -> kind option

  (* `fn_ (a, b)` is the type `a -> b`. *)
  val fn_ : ty * ty -> ty
  (* `list t` is the type `[t]`. *)
  val list : ty -> ty
  (* `tuple ts` is the tuple of the types `ts`. *)
  val tuple : ty list -> ty
  (* The unit's type, `()`. *)
  val unit : ty

  (* `apply (t, args)` is `t` applied to `args`, left to right. *)
  val apply : ty * ty list -> ty
  (* `spine t` is the head of `t` and its arguments. *)
  val spine : ty -> ty * ty list

  (* `newMeta (level, home)` is a fresh unification variable. *)
  val newMeta : int * string -> ty

  (* `repr t` follows `t`'s links to its head. *)
  val repr : ty -> ty

  (* `zonk t` is `t` with every solved variable replaced, through. *)
  val zonk : ty -> ty

  (* `metas t` is the unsolved variables of `t`, each once, in order. *)
  val metas : ty -> meta ref list

  (* `metaId m` is the number of an unsolved variable. *)
  val metaId : meta ref -> int
  (* `metaLevel m` is the level of an unsolved variable. *)
  val metaLevel : meta ref -> int
  (* `metaHome m` is the module whose code made an unsolved variable. *)
  val metaHome : meta ref -> string
  (* `setLevel (m, l)` moves an unsolved variable to the level `l`. *)
  val setLevel : meta ref * int -> unit

  (* Two types that differ, which unification cannot make one. *)
  exception Mismatch of ty * ty
  (* A variable that occurs in the type unification would make it. *)
  exception Occurs of ty * ty

  (* `unify watch (a, b)` makes `a` and `b` one type, solving variables.

     On each variable it solves, `watch` is told it and the type.

     Raises: `Mismatch` where the types differ, and `Occurs` where a
     variable would contain itself. *)
  val unify : (meta ref * ty -> unit) -> ty * ty -> unit

  (* `instantiate (s, level, home)` is `s`'s type and context with fresh
     variables for its own, and those variables. *)
  val instantiate : scheme * int * string -> ty list * pred list * ty

  (* `substGen (ts, t)` replaces `TGen i` by the `i`th of `ts`. *)
  val substGen : ty list * ty -> ty

  (* `nameOfKey k` is the name of the entity of key `k`, as a message shows
     it; a built-in name is itself. *)
  val nameOfKey : string -> string

  (* `show t` is `t` as Haskell writes it.

     Its unsolved variables are named `t1`, `t2` and on by their numbers,
     a rigid variable by its name as written. *)
  val show : ty -> string

  (* `showPred p` is the predicate `p` as a context writes it. *)
  val showPred : pred -> string

  (* `showScheme s` is the scheme `s` as a signature writes it, its
     variables `a`, `b` and on. *)
  val showScheme : scheme -> string
end
