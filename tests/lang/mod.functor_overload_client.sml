(* An overloaded operator of a functor's body settled by its client: the
   corner (a) of the deviation Functors (docs/language.md), until functors
   are compiled once (docs/plans/functors-units.md, M3 and M7).
   The Definition REJECTS it. Rule 86 elaborates the body once, and
   Appendix E gives + its default type int where "the surrounding text",
   "no larger than the smallest enclosing structure-level declaration" --
   `fun double x = x + x`, in the body -- does not resolve it: the functor's
   signature has double : int -> int, rule 54 types T.double by it, and
   T.double 1.5 is a type error.
   A compile ACCEPTS it and prints 3, a deviation: the copy of the body that
   the application elaborates for its code leaves + to the end of the
   top-level declaration -- the structure S, whose T.double 1.5 makes it
   real's. --typecheck-only, which makes no copy, REJECTS it, as the
   Definition does (.typecheck-error). *)
functor F () = struct fun double x = x + x end
structure S = struct
  structure T = F ()
  val r = T.double 1.5
end
val _ = print (Real.toString S.r ^ "\n")
