(* Word8: words of 8 bits, the element type of the byte-oriented structures.

   Implements: WORD *)
structure Word8 = RuneWordNFn (val wordSize = 8)

_overload word Word8 8
