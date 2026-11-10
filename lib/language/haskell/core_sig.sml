(* Core, rhc's typed lazy intermediate language (the haskell98 roadmap, D2):
   System F with type constructors applied to types (`m a`), a lazy `let`
   and `letrec`, and a `case` that is the only thing that forces. A value
   is passed by an atom, a variable or a literal, so every allocation is a
   `let` and every evaluation a `case`.

   A type says whether a value may be unevaluated. A binding of a lifted
   type `T` may hold a suspension; one of `!T` holds a value evaluated to
   weak head normal form. `!` stands only where a value is bound: at a
   lambda's binder, a function's parameter, a constructor's field and a
   component of an unboxed tuple, and the binder of a `case` and the
   fields it binds are of the evaluated type. So a strictness result has
   a type to go to, and Core to Mid knows which positions are `susp T` and
   which `T`. Where an evaluated value meets a lazy position, `!T` is taken
   for `T`; the other way is a `case`.

   An unlifted type, the state token `World` and an unboxed tuple, is
   never suspended: no `let` binds it, and a `case` takes it apart. `IO a`
   is `World -> (utuple World a)` in the Prelude's Core (D25).

   Area: Languages *)
signature CORE =
sig
  (* ---- Types ---- *)

  (* The kind of a type. *)
  datatype kind =
      Star                    (* a lifted type, whose values may be suspended *)
    | Unlifted                (* `World` and an unboxed tuple: always evaluated *)
    | Arrow of kind * kind    (* a type constructor, from types of one kind to another *)

  (* A type. *)
  datatype ty =
      TVar of string               (* a type variable, bound by `forall` or a type binder *)
    | TCon of string               (* a type constructor: declared by the program or built in *)
    | TApp of ty * ty              (* `f a`, a constructor or a variable applied *)
    | TFun of ty * ty              (* a function; its parameter may be `!` *)
    | TForall of string * kind * ty
    | TEval of ty                  (* `!T`: a value of `T`, evaluated *)
    | TUTuple of ty list           (* an unboxed tuple, `(utuple T ...)`; a component may be `!` *)

  (* ---- Terms ---- *)

  (* A literal. A floating literal keeps the digits it was written with. *)
  datatype lit =
      LInt of IntInf.int           (* an `Int` *)
    | LInteger of IntInf.int       (* an `Integer`, written `5I` *)
    | LChar of int                 (* a `Char`, a code point *)
    | LDouble of string            (* a `Double`, written `2.5` *)
    | LFloat of string             (* a `Float`, written `2.5F` *)
    | LStr of string               (* a `Str`, a string of bytes *)

  (* An argument: a variable or a literal. *)
  datatype atom = Var of string | Lit of lit

  (* What an application gives a function. *)
  datatype arg = TyArg of ty | ValArg of atom

  (* What a lambda binds. *)
  datatype binder = TyBinder of string * kind | ValBinder of string * ty

  (* An expression. A binder named `_` binds nothing. *)
  datatype exp =
      Atom of atom
    | App of exp * arg list                    (* a function applied to types and atoms *)
    | Lam of binder list * exp
    | Let of string * ty * exp * exp           (* a lazy `let`: the binding is suspended *)
    | LetRec of (string * ty * exp) list * exp
    | Case of exp * string * alt list          (* forces the scrutinee and binds its value *)
    | Con of string * ty list * atom list      (* a constructor of a data type, saturated *)
    | Prim of string * ty list * atom list     (* a primitive, saturated (CorePrim) *)
    | UTuple of atom list                      (* an unboxed tuple *)
    | Cast of exp * ty                         (* into or out of a newtype, at its head *)

  (* An alternative of a `case`. *)
  and alt =
      AltCon of string * string list * exp     (* a constructor and the binders of its fields *)
    | AltLit of lit * exp                      (* an `Int`, `Integer` or `Char` *)
    | AltUTuple of string list * exp           (* the components of an unboxed tuple *)
    | AltDefault of exp                        (* anything else; last *)

  (* A declaration of a program. Every value of the top level is in the
     scope of all of them. *)
  datatype decl =
      (* a data type, its parameters and its constructors, each with the
         types of its fields *)
      Data of string * (string * kind) list * (string * ty list) list
      (* a newtype, its parameters, its constructor and the type it wraps *)
    | Newtype of string * (string * kind) list * string * ty
    | Val of string * ty * exp                 (* a value of the top level *)
      (* a value of another unit, at its type (the haskell98 roadmap's M21):
         in scope as a value of the top level is, defined by the unit that
         exports it; a program of several units joined has its definition
         (CoreUnits.join) *)
    | Import of string * ty

  (* A program: what it declares, in order. `main`, of type
     `World -> (utuple World T)`, is what runs. *)
  type program = decl list

  (* ---- What is built in ---- *)

  (* `builtinTypes` is each type constructor built in with its kind: `Int`,
     `Integer`, `Char`, `Double`, `Float`, `Str`, `Exn`, `Bool`, `World`,
     `Ref` and `Arr`. *)
  val builtinTypes : (string * kind) list
  (* `builtinData` is the data types built in: `Bool`, whose constructors
     `False` and `True` are 0 and 1, as Mid's `bool`. *)
  val builtinData : decl list

  (* ---- Types, taken apart and compared ---- *)

  (* `stripEval t` is `t` without a `!` at its head. *)
  val stripEval : ty -> ty
  (* `isEval t` is whether `t` has a `!` at its head. *)
  val isEval : ty -> bool
  (* `spine t` is the head of the type application `t` and its arguments. *)
  val spine : ty -> ty * ty list
  (* `apply (t, args)` applies `t` to `args`, left to right. *)
  val apply : ty * ty list -> ty
  (* `freeTyVars t` is the type variables free in `t`, each once. *)
  val freeTyVars : ty -> string list
  (* `substTy (s, t)` replaces each variable of `s` free in `t` by its type,
     renaming a binder of `t` that would capture a variable of those types. *)
  val substTy : (string * ty) list * ty -> ty
  (* `equalTy (a, b)` is whether `a` and `b` are the same type, up to the
     names of their bound variables. *)
  val equalTy : ty * ty -> bool
  (* `litTy l` is the type of the literal `l`, without `!`. *)
  val litTy : lit -> ty
  (* `lamTy (binders, t)` is the type of a lambda of `binders` whose body
     has type `t`. *)
  val lamTy : binder list * ty -> ty
end
