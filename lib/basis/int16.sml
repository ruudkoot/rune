(* Int16: integers of 16 bits.

   Implements: INTEGER

   Status: optional *)
structure Int16 = RuneIntNFn (val precision = 16)

_overload int Int16 16
