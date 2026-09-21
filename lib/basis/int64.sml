(* Int64: the 64-bit integers, and FixedInt, the largest of the
   fixed-precision ones, which is the same structure.

   The implementation is `Int`, whose width the VM decides, but the type is
   sealed away from `Int.int` so that no program can take the two for one:
   `Int` is of no fixed width as far as a program can see, which leaves the
   VM free to choose it. Every operation is `Int`'s, so the seal costs
   nothing; `toInt` and `fromInt` are the way between them, as the
   specification intends.

   Implements: INTEGER

   Status: optional *)
structure Int64 :> INTEGER = Int
(* The largest fixed-precision integer: `Int` is of no fixed precision here,
   so it is the 64-bit one.

   Implements: INTEGER where type int = Int64.int

   Status: optional *)
structure FixedInt = Int64

_overload int Int64 64
