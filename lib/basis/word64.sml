(* Word64: the 64-bit words.

   The implementation is `Word`, whose width the VM decides, but the type is
   sealed away from `Word.word` so that no program can take the two for one,
   which leaves the VM free to choose the width of `Word`. Every operation is
   `Word`'s, so the seal costs nothing.

   Implements: WORD

   Status: optional *)
structure Word64 :> WORD = Word

_overload word Word64 64
