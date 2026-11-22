(* The type constructors of Haskell 98's checker and their kinds (the
   haskell98 roadmap's M13; the Report's 4.6): kind inference over a
   unit's `data`, `newtype`, `type` and `class` declarations by dependency
   group, a kind left open defaulting to `*`, so that a type group may
   cross the modules of a cycle (R28, D30); the kind checking of every
   other type a program writes; and the types of the tree made the
   checker's, synonyms expanded.

   Area: Languages *)
signature HS_KINDS =
sig
  (* A type constructor: its key, its kind and the number of its
     parameters.

     With them, its right-hand side over `TGen 0` and on, for a synonym,
     its constructors' keys, for `data` and `newtype`, and whether it is a
     newtype. *)
  type tycon = {key : string, kind : HsTypes.kind, params : int, synonym : HsTypes.ty option,
                cons : string list, newtype : bool}

  (* The type constructors of a program, by key. *)
  type env = tycon HsStringMap.map

  (* `find (env, key)` is the type constructor of `key`, the built-in
     ones among them. *)
  val find : env * string -> tycon option

  (* `keyOf n` is the key of the type constructor or class the name `n`
     of the renamed tree stands for. *)
  val keyOf : HsAst.name -> string

  (* `infer {env, classKind, decls}` infers the kinds of `decls`, the
     type-level declarations of a unit, each with its module's identity.

     It gives the environment with their type constructors, the kinds of
     the unit's classes' variables, by the class's key, and the errors.
     `classKind` gives the kind of a class of an earlier unit. *)
  val infer : {env : env, classKind : string -> HsTypes.kind option, decls : (string * HsAst.decl) list}
              -> {env : env, classKinds : (string * HsTypes.kind) list, errors : (HsSource.span * string) list}

  (* `checkType {env, classKind, vars} (t, want)` checks that the type `t`
     is well kinded, of kind `want`.

     Its variables' kinds are in `vars`, which it extends.

     Raises: `HsSource.Error` for a type ill kinded. *)
  val checkType : {env : env, classKind : string -> HsTypes.kind option, vars : HsTypes.kind HsStringMap.map ref}
                  -> HsAst.ty * HsTypes.kind -> unit

  (* `checkContext {env, classKind, vars} ctx` checks each class
     assertion of the context `ctx`. *)
  val checkContext : {env : env, classKind : string -> HsTypes.kind option, vars : HsTypes.kind HsStringMap.map ref}
                     -> HsAst.ty option -> unit

  (* `convert (env, var) t` is the type `t` as the checker's, its
     variables by `var`.

     Its synonyms are expanded.

     Raises: `HsSource.Error` for a synonym not applied to all its
     parameters. *)
  val convert : env * (string -> HsTypes.ty) -> HsAst.ty -> HsTypes.ty

  (* `contextPreds (env, var) ctx` is the predicates of a context. *)
  val contextPreds : env * (string -> HsTypes.ty) -> HsAst.ty option -> HsTypes.pred list

  (* `tyVars t` is the type variables of `t`, each once, in order. *)
  val tyVars : HsAst.ty -> string list
end
