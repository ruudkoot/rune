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
end
