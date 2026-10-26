(* An overloaded operator of a functor's body, which a compile left to its
   client while it typed an application by a copy of the body
   (docs/plans/functors-units.md, corner (a), closed by M7).
   The Definition REJECTS it, and so does every mode now. Rule 86
   elaborates the body once, and Appendix E gives + its default type int
   where "the surrounding text", "no larger than the smallest enclosing
   structure-level declaration" -- `fun double x = x + x`, in the body --
   does not resolve it: the functor's signature has double : int -> int,
   rule 54 types T.double by it, and T.double 1.5 is a type error. The copy
   of the body left + to the structure S, whose T.double 1.5 made it
   real's, and printed 3. *)
functor F () = struct fun double x = x + x end
structure S = struct
  structure T = F ()
  val r = T.double 1.5
end
val _ = print (Real.toString S.r ^ "\n")
