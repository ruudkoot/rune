(* What desugaring knows of a checked program (the haskell98 roadmap's
   M15): its names, types, records and dictionaries in Core.

   It holds the names the program's entities have in Core, its types made
   Core's, the checker's evidence records (D31) by node, its dictionaries,
   and the primitives of rhc's library made functions of Haskell's types.

   An entity of the top level is named in Core by its module's identity, a
   dot and its name, haskell98:Prelude.map or Main.f; a local keeps the
   renamer's unique name, x#3. What desugaring makes has a name starting
   with %: a class's dictionary constructor, %dict:C, an instance's
   dictionary function, %inst:C@T, a superclass's selector, %super:C>S, a
   class's default method, %dm:m.

   Types: a type constructor of the program is named as its entity; the
   Prelude's `Bool` is Core's `Bool`, and a type that a module of the
   library declares with no constructor is Core's own (`Int`, `Integer`,
   `Char`, `Float`, `Double`, `Str`, `Ref`), PreludeIO's `IOError` Core's
   `Exn`, and `IO` the newtype `IO` over `World -> (utuple World a)` (D25),
   a type constructor of its own so that `Monad IO` has a dictionary. A
   class is the data type of its dictionaries, of the same name: its
   direct superclasses' dictionaries, then its methods, each of the type
   of its own scheme.

   Area: Languages *)
signature HS_DS_ENV =
sig
  (* ---- The program ---- *)

  (* What a desugaring is given: the checker's environment and records, and
     how to find the entities the translations name.

     They are the checker's environment after the last unit, its evidence
     records, the key of what the Prelude exports by space (`"v"` or `"t"`)
     and name, whether a module's identity is the library's, and the key of
     an entity of a module of the library by its space, the module's name
     and its name: Ratio's `:%`, which a floating literal is made of, though
     the Prelude does not export it (E9). *)
  type program = {infer : HsInfer.env, evidence : HsEvidence.table, prelude : string * string -> string option,
                  library : string -> bool, entity : string * string * string -> string}

  (* `start p` makes `p` the program desugared, forgetting the last. *)
  val start : program -> unit

  (* `continue p` makes `p` the program desugared, keeping what is known of
     its types and constructors: a program's, after its library's. *)
  val continue : program -> unit

  (* What is known of the types and constructors, kept. *)
  type saved

  (* `save ()` is what is known now. *)
  val save : unit -> saved

  (* `restore s` makes `s` what is known. *)
  val restore : saved -> unit

  (* What is known of the types and constructors, as lists, for a unit's
     interface.

     Each type of the library made Core's own, by key, Bool's constructors,
     and each constructor's fields, by key. *)
  type known = {primTypes : (string * string) list, builtinCons : (string * string) list,
                fields : (string * string list) list}

  (* `known ()` is what is known now, each list by key. *)
  val known : unit -> known

  (* `learn k` adds `k` to what is known. *)
  val learn : known -> unit

  (* `classes ()` is the program's classes and instances. *)
  val classes : unit -> HsClasses.env

  (* `valueScheme key` is the type the checker gave the value `key`. *)
  val valueScheme : string -> HsTypes.scheme option

  (* `prelude (space, name)` is the key of what the Prelude exports.

     Raises: `Fail` where it exports no such name, a fault of the
     library. *)
  val prelude : string * string -> string

  (* `isLibrary id` is whether the module of identity `id` is the
     library's. *)
  val isLibrary : string -> bool

  (* `libraryEntity (space, module, name)` is the key of an entity of a
     module of the library. *)
  val libraryEntity : string * string * string -> string

  (* `setFields (con, fields)` records the fields of the constructor
     `con`, by their keys in order, `""` for one without a name. *)
  val setFields : string * string list -> unit

  (* `fieldsOf con` is the fields of the constructor `con`. *)
  val fieldsOf : string -> string list

  (* ---- Names ---- *)

  (* `coreName key` is the Core name of the entity `key`. *)
  val coreName : string -> string

  (* `valueKey n` is the key of the value the name `n` of the renamed tree
     stands for.

     It is a top-level entity's key, a local's own name, or a built-in
     constructor's (`()`, `[]`, `:`, `(,)`). *)
  val valueKey : HsAst.name -> string

  (* `homeOf key` and `nameOf key` are the parts of an entity's key. *)
  val homeOf : string -> string
  val nameOf : string -> string

  (* `tyconName key` is the type constructor of Core that the type
     constructor `key` is. *)
  val tyconName : string -> string

  (* `conName key` is the constructor of Core that the data constructor
     `key` is. *)
  val conName : string -> string

  (* `primType (key, core)` makes the type `key`, which a module of the
     library declares with no constructor, Core's type `core`. *)
  val primType : string * string -> unit

  (* `isPrimType key` is whether the type `key` is Core's own. *)
  val isPrimType : string -> bool

  (* `builtinCon (key, core)` makes the constructor `key` Core's `core`,
     as the Prelude's `True` is Core's. *)
  val builtinCon : string * string -> unit

  (* `dictCon cls` is the constructor of the dictionaries of the class
     `cls`. *)
  val dictCon : string -> string

  (* `dfunName id` is the dictionary function of the instance `id`. *)
  val dfunName : string -> string

  (* `superName (cls, super)` is the selector of the superclass `super`
     from a dictionary of `cls`. *)
  val superName : string * string -> string

  (* `defaultName method` is the default of the method `method`. *)
  val defaultName : string -> string

  (* ---- Scopes ---- *)

  (* What is in scope where an expression is desugared.

     It holds the variables, each the atom of Core it is and its type,
     dictionary parameters among them, and the type variables with their
     kinds. *)
  type env

  (* `empty` is the scope of the top level. *)
  val empty : env

  (* `bind (env, x, atom, t)` is `env` with `x` the atom `atom` of type
     `t`. *)
  val bind : env * string * Core.atom * Core.ty -> env

  (* `lookup (env, x)` is the atom `x` is and its type. *)
  val lookup : env * string -> (Core.atom * Core.ty) option

  (* `bindTypes (env, vars)` is `env` with the type variables `vars`. *)
  val bindTypes : env * (string * Core.kind) list -> env

  (* `typeVars env` is the type variables in scope. *)
  val typeVars : env -> (string * Core.kind) list

  (* ---- Types ---- *)

  (* `ty env t` is the Core type of `t`, a closed type of the records.

     A rigid variable not in scope stands for nothing a value can be of, a
     variable of another binding of a group that this one's type does not
     hold, and is `()`. *)
  val ty : env -> HsTypes.ty -> Core.ty

  (* `tyGen (env, gens) t` is the Core type of `t`, whose `TGen i` is the
     `i`th of `gens`. *)
  val tyGen : env * Core.ty list -> HsTypes.ty -> Core.ty

  (* `predTy env p` is the type of the dictionaries of the predicate `p`. *)
  val predTy : env -> HsTypes.pred -> Core.ty

  (* `scheme env s` is the type of a value of the scheme `s` of the
     records, and its variables with their kinds.

     The type is a forall over its variables, with their kinds, of a
     function of its context's dictionaries, in order, giving its type. *)
  val scheme : env -> HsEvidence.scheme -> Core.ty * (string * Core.kind) list

  (* `genScheme s` is the type of a value of the checker's scheme `s`, its
     variables named `g1`, `g2` and on. *)
  val genScheme : HsTypes.scheme -> Core.ty

  (* `ioTy t` is `IO t`. *)
  val ioTy : Core.ty -> Core.ty

  (* ---- Records ---- *)

  (* `records (kind, span)` is the records at a node. *)
  val records : string * HsSource.span -> HsEvidence.record list

  (* `useOf span` is the types and dictionaries of the variable or
     constructor used at `span`. *)
  val useOf : HsSource.span -> {tys : HsTypes.ty list, dicts : HsEvidence.dict list}

  (* `bindOf span` is the record of the binder at `span`. *)
  val bindOf : HsSource.span -> HsEvidence.record option

  (* `overloadedOf (kind, span)` is the type and the dictionaries by class
     of a construct the Report translates through a class. *)
  val overloadedOf : string * HsSource.span -> HsTypes.ty * (string * HsEvidence.dict) list

  (* ---- Expressions ---- *)

  (* `dict env d` is the dictionary `d`. *)
  val dict : env -> HsEvidence.dict -> HsDsCore.texp

  (* `instantiate env (f, tys, dicts)` is `f` at the types `tys` and the
     dictionaries `dicts`, as a use's record gives them. *)
  val instantiate : env -> HsDsCore.texp * HsTypes.ty list * HsEvidence.dict list -> HsDsCore.texp

  (* `global key` is the value `key` of the top level, at its type, before
     any is given it. *)
  val global : string -> HsDsCore.texp

  (* `method env (key, tys, dicts)` is the value `key`, a method of the
     Prelude's or a function, at the Core types `tys` and the dictionaries
     `dicts`. *)
  val method : env -> string * Core.ty list * HsDsCore.texp list -> HsDsCore.texp

  (* `superDict env (d, cls, super)` is the dictionary of `super`, a
     superclass of `cls`, taken from `d`, a dictionary of `cls`.

     It goes by the path of direct superclasses between them. *)
  val superDict : env -> HsEvidence.dict * string * string -> HsEvidence.dict

  (* `integerLit env (i, t, num)` is the integer literal `i` at the type
     `t`, of which `num` is the `Num` dictionary.

     It is `fromInteger i` (3.2), but an `Int` in range or an `Integer`
     itself, where `num` is the Prelude's instance at that type. *)
  val integerLit : env -> IntInf.int * HsTypes.ty * HsEvidence.dict -> HsDsCore.texp

  (* `rationalLit env (text, t, fractional)` is the floating literal
     written `text` at the type `t`.

     It is `fromRational` of Ratio's `n :% d`, `n/d` its value in lowest
     terms (3.2), but a `Double` or a `Float` itself where `fractional` is
     the Prelude's instance at that type. *)
  val rationalLit : env -> string * HsTypes.ty * HsEvidence.dict -> HsDsCore.texp

  (* `stringLit chars` is a string literal of the code points `chars`.

     Its bytes in UTF-8 are unpacked lazily by the runtime's
     `primUnpackString` (D24's A). *)
  val stringLit : int list -> HsDsCore.texp

  (* `toHaskell (x, want)` is `x`, a value of a type of Core's own making,
     as a value of `want`, the Core type of a Haskell type.

     A primitive's `!` parameters are forced, and an action
     `World -> (utuple World a)` is made `IO a`.

     Raises: `Fail` where the two differ otherwise. *)
  val toHaskell : HsDsCore.texp * Core.ty -> HsDsCore.texp

  (* `matchType (pattern, vars, t)` is the types that `vars`, variables of
     `pattern`, stand for where `pattern` is `t`.

     The two are compared as `toHaskell` sees them; `NONE` where they
     differ. *)
  val matchType : Core.ty * string list * Core.ty -> Core.ty list option

  (* `haskellForm t` is the type of Core's own making `t` as Haskell sees
     it: no `!`, and `IO a` for `World -> (utuple World a)`. *)
  val haskellForm : Core.ty -> Core.ty
end
