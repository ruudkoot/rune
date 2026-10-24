(* A constant of a functor's body settled by its client: the corner (a) of
   the deviation Functors (docs/language.md), until functors are compiled
   once (docs/plans/functors-units.md, M3 and M7).
   The Definition REJECTS it. Appendix E gives the constant 1 the default
   type int in the smallest structure-level declaration that holds it,
   `val one = 1` of the body, which rule 86 elaborates once: the functor's
   signature has one : int, and rule 54 types T.one by it, not at
   Int64.int.
   A compile ACCEPTS it and prints 1, a deviation: the copy of the body that
   the application elaborates for its code leaves the constant to the end
   of the top-level declaration, the structure S. --typecheck-only, which
   makes no copy, REJECTS it, as the Definition does (.typecheck-error). *)
functor F () = struct val one = 1 end
structure S = struct
  structure T = F ()
  val x : Int64.int = T.one
end
val _ = print (Int64.toString S.x ^ "\n")
