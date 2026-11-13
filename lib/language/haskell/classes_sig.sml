(* The classes and instances of Haskell 98's checker (the haskell98
   roadmap's M13; the Report's 4.3): every class and instance of the
   program, for entailment. Instances are not names: every instance a
   program declares, or derives, is in force in all of it.

   Area: Languages *)
signature HS_CLASSES =
sig
  (* A class: its key, its direct superclasses, its methods' keys, in
     order, and the kind of its variable. *)
  type class = {key : string, supers : string list, methods : string list, kind : HsTypes.kind}

  (* An instance `C (T a1 ... an)`: its identity, class, type constructor
     and the number of its head's variables.

     With them, its context over `TGen 0` to `TGen (n - 1)`, whether it is
     derived, and the module that declares it. *)
  type instance = {id : string, cls : string, tycon : string, vars : int, ctx : HsTypes.pred list,
                   derived : bool, home : string}

  (* The classes and instances of a program. *)
  type env

  (* No class and no instance. *)
  val empty : env
  (* `addClass (env, c)` is `env` with the class `c`. *)
  val addClass : env * class -> env
  (* `addInstance (env, i)` is `env` with the instance `i`. *)
  val addInstance : env * instance -> env

  (* `withContext (env, id, ctx)` is `env` with the context of the
     instance `id` replaced, as deriving's fixpoint does. *)
  val withContext : env * string * HsTypes.pred list -> env

  (* `findClass (env, key)` is the class of `key`. *)
  val findClass : env * string -> class option
  (* `findInstance (env, cls, tycon)` is the instance of `cls` at `tycon`,
     a read of the instance's, found or not (HsUsage, H2). *)
  val findInstance : env * string * string -> instance option
  (* `instances env` is every instance of `env`. *)
  val instances : env -> instance list

  (* `classList env` is every class of `env`. *)
  val classList : env -> class list

  (* `instanceId (cls, tycon)` is the identity of the instance of `cls`
     at `tycon`. *)
  val instanceId : string * string -> string

  (* `showInstance id` is the instance `id` as a message names it: its
     class and its type constructor. *)
  val showInstance : string -> string

  (* `superPath (env, c, s)` is the classes from `c` to its superclass `s`,
     `c` first and `s` last.

     Each is the direct superclass of the one before; NONE where `s` is no
     superclass of `c`. *)
  val superPath : env * string * string -> string list option

  (* `superclasses (env, c)` is every superclass of `c`, through. *)
  val superclasses : env * string -> string list
end
