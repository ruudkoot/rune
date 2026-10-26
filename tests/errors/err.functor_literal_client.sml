(* A constant of a functor's body, which a compile left to its client
   while it typed an application by a copy of the body
   (docs/plans/functors-units.md, corner (a), closed by M7).
   The Definition REJECTS it, and so does every mode now. Appendix E gives
   the constant 1 the default type int in the smallest structure-level
   declaration that holds it, `val one = 1` of the body, which rule 86
   elaborates once: the functor's signature has one : int, and rule 54
   types T.one by it, not at Int64.int. The copy of the body left the
   constant to the end of the top-level declaration, the structure S, and
   printed 1. *)
functor F () = struct val one = 1 end
structure S = struct
  structure T = F ()
  val x : Int64.int = T.one
end
val _ = print (Int64.toString S.x ^ "\n")
