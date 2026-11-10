(* Core as desugaring builds it (the haskell98 roadmap's M15): each
   expression with its type.

   An expression is made with its type, worked out from its parts as
   CoreLint works it out, so that an argument that is not an atom can be
   bound by a `let` of its type; and the declarations of the program being
   built are kept, by which a constructor's fields and a newtype's
   unfolding are known.

   A name made here starts with `%`, which no name of Haskell's holds,
   neither a top-level entity's nor a local's (`x#3`).

   Area: Languages *)
signature HS_DS_CORE =
sig
  (* An expression and its type. *)
  type texp = Core.exp * Core.ty

  (* What a type constructor of the program is. *)
  datatype shape =
      DataS of (string * Core.ty list) list    (* a data type: its constructors and their fields *)
    | NewS of string * Core.ty                 (* a newtype: its constructor and the type it wraps *)
    | PrimS                                    (* a type of Core's own: `Int`, `World`, ... *)

  (* `reset ()` forgets every declaration and starts the names again. *)
  val reset : unit -> unit

  (* `fresh base` is a new name, `%base` and a number. *)
  val fresh : string -> string

  (* ---- The declarations ---- *)

  (* `declare d` adds the data type, newtype or value `d` to what is known.

     A value is known by its type. *)
  val declare : Core.decl -> unit

  (* `tycon c` is the parameters and the shape of the type constructor `c`,
     Core's built-in ones among them. *)
  val tycon : string -> ((string * Core.kind) list * shape) option

  (* `conInfo k` is the type constructor of the constructor `k`, its
     parameters and its fields' types over them. *)
  val conInfo : string -> {tycon : string, params : (string * Core.kind) list, fields : Core.ty list} option

  (* `fieldsAt (k, args)` is the types of the fields of the constructor `k`
     of a type applied to `args`.

     Raises: `Fail` where `k` is not declared. *)
  val fieldsAt : string * Core.ty list -> Core.ty list

  (* `valueType x` is the type of the value `x` of the top level, or of
     rhc's runtime. *)
  val valueType : string -> Core.ty option

  (* `unfold t` is `t` unfolded once, where a newtype is at its head. *)
  val unfold : Core.ty -> Core.ty option

  (* `dataArgs t` is the type constructor at the head of `t`, a data type's
     or a newtype's, and its arguments. *)
  val dataArgs : Core.ty -> (string * Core.ty list) option

  (* ---- Types ---- *)

  (* `kindOf (vars, t)` is the kind of the type `t`, whose variables have
     the kinds `vars` or are of `*`. *)
  val kindOf : (string * Core.kind) list * Core.ty -> Core.kind

  (* `inferKinds (vars, known, tys)` is the kind of each of `vars`, which
     the types `tys` of kind `*` hold.

     Each is worked out from where it stands, and is `*` where nothing
     says; `known` gives the kinds of the other variables. *)
  val inferKinds : string list * (string -> Core.kind option) * Core.ty list -> (string * Core.kind) list

  (* `instantiate (t, tys)` is `t` without its first foralls, their
     variables replaced by `tys`, in order. *)
  val instantiate : Core.ty * Core.ty list -> Core.ty

  (* `applyType (t, args)` is the type of a function of type `t` given
     `args`. *)
  val applyType : Core.ty * Core.arg list -> Core.ty

  (* `params (t, n)` is the types of the first `n` parameters of a
     function of type `t`, and the type of what it gives then.

     Raises: `Fail` where `t` takes fewer. *)
  val params : Core.ty * int -> Core.ty list * Core.ty

  (* `lazyTy t` is `t` as a lazy binding holds it: without `!`. *)
  val lazyTy : Core.ty -> Core.ty

  (* ---- Expressions ---- *)

  (* `atom (x, k)` gives `k` the atom of `x`: itself where it is one,
     otherwise a variable bound to it by a lazy `let`. *)
  val atom : texp * (Core.atom * Core.ty -> texp) -> texp

  (* `atoms (xs, k)` is `atom` over each of `xs`, left to right. *)
  val atoms : texp list * ((Core.atom * Core.ty) list -> texp) -> texp

  (* `var (x, t)` is the variable `x` of type `t`. *)
  val var : string * Core.ty -> texp

  (* `app (f, args)` is `f` applied to `args`; `f` itself where there are
     none. *)
  val app : texp * Core.arg list -> texp

  (* `appAtoms (f, xs)` is `f` applied to the atoms of `xs`, each bound by
     `atom`. *)
  val appAtoms : texp * texp list -> texp

  (* `lam (binders, body)` is a lambda of `binders`; `body` itself where
     there are none. *)
  val lam : Core.binder list * texp -> texp

  (* `let_ (x, t, rhs, body)` is `let x : t = rhs in body`, `t` lazy. *)
  val let_ : string * Core.ty * texp * texp -> texp

  (* `letrec (bs, body)` binds `bs`, each with its lazy type, in each
     other and in `body`; `body` itself where there are none. *)
  val letrec : (string * Core.ty * texp) list * texp -> texp

  (* `force (x, k)` evaluates `x` by a `case` and gives `k` the evaluated
     variable and its type. *)
  val force : texp * (string * Core.ty -> texp) -> texp

  (* `caseCon (x, ty, alts, default)` is a `case` on the atom `x` of the
     data type `ty`.

     It has an alternative for each constructor of `alts`, made of its
     fields' names and types, and `default` for the others, left out where
     `alts` covers them all.

     Raises: `Fail` where `ty` is not a data type. *)
  val caseCon : Core.atom * Core.ty * (string * ((string * Core.ty) list -> texp)) list * texp option -> texp

  (* `ifBool (c, t, e)` is `case c of True -> t; False -> e`. *)
  val ifBool : texp * texp * texp -> texp

  (* `con (k, tys, xs)` is the constructor `k` at the types `tys` applied
     to the atoms of `xs`. *)
  val con : string * Core.ty list * texp list -> texp

  (* `cast (x, t)` is `x` cast to the type `t`, into or out of a newtype. *)
  val cast : texp * Core.ty -> texp

  (* `fail (kind, message, t)` is an expression of type `t` that raises
     the exception the primitive `kind` makes of `message`.

     `kind` is `exn_pattern` for a match that fails, `exn_error` for
     `error`'s. It calls one of `raisers`, at `t`. *)
  val fail : string * string * Core.ty -> texp

  (* `mentions (x, e)` is whether the variable `x` occurs in `e`, which
     binds no other `x`. *)
  val mentions : string * Core.exp -> bool

  (* `names e` is every variable `e` holds, bound in it or not, and every
     constructor, each once. *)
  val names : Core.exp -> string list

  (* `raisers` is the values `fail` calls, a declaration each, which a
     program that uses `fail` holds. *)
  val raisers : Core.decl list

  (* `unitTy` is the type of Haskell's `()`, rhc's runtime's. *)
  val unitTy : Core.ty

  (* `unitVal ()` is the value `()`. *)
  val unitVal : unit -> texp
end
