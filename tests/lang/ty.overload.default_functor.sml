(* --default-type=int64 holds in the input files and not in the libraries
   (docs/language.md, Default types), so the Basis Library's functor
   RunePackRealFn, whose `val bytesPerElem = 8` leaves the constant to its
   default (Appendix E), is elaborated once (rule 86) with int: its
   signature has bytesPerElem : int, and rule 54 types P.bytesPerElem by it.
   With the option's meaning, the Definition ACCEPTS this program, and so
   does every mode now; a compile that typed an application by a copy of
   the body elaborated the copy in the input file, with Int64.int, and
   refused it (docs/plans/functors-units.md, corner (d), closed by M7). *)
structure P = RunePackRealFn (val isBigEndian = true)
val n : int = P.bytesPerElem
val _ = print (Int.toString n ^ "\n")
