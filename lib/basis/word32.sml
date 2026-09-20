(* Word32: words of 32 bits. *)
structure Word32 = RuneWordNFn (val wordSize = 32)

_overload word Word32 32
