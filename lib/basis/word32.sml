(* Word32: words of 32 bits.

   Implements: WORD

   Status: optional *)
structure Word32 = RuneWordNFn (val wordSize = 32)

_overload word Word32 32
