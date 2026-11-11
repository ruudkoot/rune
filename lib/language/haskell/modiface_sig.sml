(* A module's interface as the renamer and the checker make it (the
   haskell98 roadmap's M21, D44): what a client of the module needs of it
   to be named and checked against it in place of its source, by entity,
   and the fingerprints a store's usages compare (E13's H5, H6). HsIface,
   rhc's interface of a unit, holds one for each of its modules beside its
   Core, and codes them.

   Area: Languages *)
signature HS_MOD_IFACE =
sig
  (* A module's interface, what a client is named and checked by.

     It holds the module's identity; what it exports, by entity, as
     HsModules solved them; what it defines at its top level, with its
     sort, parent and arity, which an import of `T(..)` reads; the
     fixities of its operators, by entity key; and its part of the
     checker's environment. *)
  type t = {id : string, exports : HsModules.entity list, defs : HsModules.def list,
            fixities : (string * (HsAst.fixity * int)) list, checked : HsInfer.part}

  (* `make {id, exports, defs, fixity, env}` is the interface of the module
     `id`, from the program's tables after its unit is checked.

     `fixity key` is the fixity of an operator, and `env` the checker's
     environment. *)
  val make : {id : string, exports : HsModules.entity list, defs : HsModules.def list,
              fixity : string -> (HsAst.fixity * int) option, env : HsInfer.env} -> t

  (* `canonical t` is each item of the interface by its key, with the text
     that stands for what a client reads of it.

     An item is a type with its constructors and fields, a class with its
     methods, a value, or an instance by its identity; its text holds keys,
     kinds, schemes over `TGen` numbers, contexts, and the fixities of its
     names. Two interfaces that a client reads alike have the same text. *)
  val canonical : t -> (string * string) list

  (* `fingerprints hash (t, external)` is the fingerprint of each entity
     and instance of `t`, by its key or identity.

     A type's constructors and fields and a class's methods have their
     parent's.

     Items are taken in recursive groups (one mentions another, through a
     type, a class, a superclass, an instance's class, type or context): a
     group's fingerprint is `hash` of its members' canonical text and of
     the fingerprints of the entities outside the module they mention,
     `external key` (the key itself where that is NONE: a built-in type),
     so that it moves where what a client reads of it moves, and with what
     it mentions. *)
  val fingerprints : (string -> string) -> t * (string -> string option) -> (string * string) list
end
