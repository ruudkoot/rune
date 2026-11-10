(* Haskell 98's derived instances (the Report's chapter 10; the haskell98
   roadmap's M14, D33's C): the methods of a derived `Eq`, `Ord`, `Enum`,
   `Bounded`, `Ix`, `Show` or `Read` instance, made as the renamed tree a
   user would write, with chapter 10's text as the specification, so that
   the checker elaborates them as it does a user's instance and HsLint
   checks them as any instance (D54).

   The checker infers the instance's context (10.1, HsInfer) and checks
   what this makes. The tree names entities, not text: a derived `Ix` in
   Time uses methods Time does not import (E16). Records are shown and
   read as `C {f = v}` at precedence 11 (R41, GHC's row, which Haskell
   2010 took); an infix constructor by its fixity (10.4).

   Area: Languages *)
signature HS_DERIVE =
sig
  (* A constructor of the data type, as deriving reads it.

     Its name, as the renamed tree has it, the number of its fields,
     their names for a record, whether it is declared infix
     (`isInfix`), and its fixity. *)
  type constr = {name : HsAst.name, arity : int, fields : HsAst.name list, isInfix : bool,
                 fixity : HsAst.fixity * int}

  (* `methods {cls, constrs, entity, file}` is the method bindings of the
     derived instance of the class `cls`, a key, at the data type of
     `constrs`.

     `entity (space, name)` is the key of a standard entity by name,
     `"v"` or `"t"`: the Prelude's, and Ix's `range`, `index`, `inRange`
     and `rangeSize`. `file` names the nodes' spans, each of its own, so
     that the evidence of each is apart; NONE where `cls` is no class
     that can be derived. *)
  val methods : {cls : string, constrs : constr list, entity : string * string -> string option, file : string}
                -> HsAst.decl list option
end
