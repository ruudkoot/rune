(* Int8: integers of 8 bits.

   Implements: INTEGER

   Status: optional *)
structure Int8 = RuneIntNFn (val precision = 8)

_overload int Int8 8
