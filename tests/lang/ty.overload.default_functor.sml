(* --default-type=int64 and a functor of the Basis Library, the other way
   round from tests/errors/err.functor_default_type: RunePackRealFn's
   signature has bytesPerElem : int (rule 86, with the libraries' default),
   and rule 54 types P.bytesPerElem by it, so the Definition, with the
   option's meaning, REJECTS P.bytesPerElem at Int64.int.
   A compile ACCEPTS it and prints 8, a deviation, the corner (d) of the
   deviation Functors (docs/language.md), until functors are compiled once
   (docs/plans/functors-units.md, M3 and M7): the copy of the body that the
   application elaborates for its code is elaborated in the input file,
   with Int64.int. --typecheck-only, which makes no copy, REJECTS it, as the
   Definition does (.typecheck-error). *)
structure P = RunePackRealFn (val isBigEndian = true)
val n : Int64.int = P.bytesPerElem
val _ = print (Int64.toString n ^ "\n")
