(* --default-type=int64 holds in the input files and not in the libraries
   (docs/language.md, Default types), so the Basis Library's functor
   RunePackRealFn, whose `val bytesPerElem = 8` leaves the constant to its
   default (Appendix E), is elaborated once (rule 86) with int: its
   signature has bytesPerElem : int, and rule 54 types P.bytesPerElem by it.
   With the option's meaning, the Definition ACCEPTS this program.
   A compile REFUSES it, a deviation, the corner (d) of the deviation
   Functors (docs/language.md), until functors are compiled once
   (docs/plans/functors-units.md, M3 and M7): the copy of the body that the
   application elaborates for its code is elaborated in the input file,
   with Int64.int. --typecheck-only, which makes no copy, ACCEPTS it, as the
   Definition does (.typecheck-ok) *)
structure P = RunePackRealFn (val isBigEndian = true)
val n : int = P.bytesPerElem
val _ = print (Int.toString n ^ "\n")
