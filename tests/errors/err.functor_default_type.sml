(* --default-type=int64 and a functor of the Basis Library, the other way
   round from tests/lang/ty.overload.default_functor: RunePackRealFn's
   signature has bytesPerElem : int (rule 86, with the libraries' default),
   and rule 54 types P.bytesPerElem by it, so the Definition, with the
   option's meaning, REJECTS P.bytesPerElem at Int64.int, and so does every
   mode now. A compile that typed an application by a copy of the body
   elaborated the copy in the input file, with Int64.int, and printed 8
   (docs/plans/functors-units.md, corner (d), closed by M7). *)
structure P = RunePackRealFn (val isBigEndian = true)
val n : Int64.int = P.bytesPerElem
val _ = print (Int64.toString n ^ "\n")
