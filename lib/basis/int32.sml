(* Int32: integers of 32 bits.

   Implements: INTEGER

   Status: optional *)
structure Int32 = RuneIntNFn (val precision = 32)

_overload int Int32 32
