(* Core in units (the haskell98 roadmap's M21): a program of several units,
   each a Core program that names what it takes of the others, a value by
   an import (`(import x TYPE)`) and a type by a copy of its declaration,
   joined into one program, which Core's interpreter runs and a compile
   whole takes. *)
signature CORE_UNITS =
sig
  (* what makes units that do not join: a type two units declare apart, or
     an import at another type than its definition's *)
  exception Error of string

  (* `join units` is the program of the units, in order, each type
     declared once and each import given its definition.

     A data type or newtype is kept where it is first declared, every unit
     that declares it declaring the same; an import is dropped where a unit
     defines its value, at the type the import gives it, and kept where
     none does. *)
  val join : Core.program list -> Core.program

  (* `unresolved p` is the imports of p that no declaration of p defines,
     in order *)
  val unresolved : Core.program -> string list

  (* `interface (p, exports)` is what a client of the unit p needs of the
     names it exports, as Core: each type it mentions declared, and each
     value imported.

     Each exported value is an import at its type, and each exported type
     and every type the exports' types mention, through the types' own
     fields, is declared as p declares it, in p's order; a name p does not
     declare is a built-in type's, or another unit's the client has. *)
  val interface : Core.program * string list -> Core.program

  (* `fingerprints hash iface` is each declaration of the interface by its
     name with its fingerprint, which moves where what a client reads of it
     moves.

     A type's is its recursive group's: the hash of the group's
     declarations and of the fingerprints of the types outside it that they
     mention, so that a group hashes as one. A value's is the hash of its
     type and of the fingerprints of the types it mentions. A type no
     declaration of the interface gives is its name. *)
  val fingerprints : (string -> string) -> Core.program -> (string * string) list
end
