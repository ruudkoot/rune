(* requires: Int Position LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int matches INTEGER, and Int.int is the top-level int. Position, the
   positions of a file, matches it as well; here it is Int. *)
structure TestIntSig =
struct
  structure C : SPEC_INTEGER = Int
  val () = T.check ("Int:INTEGER/matches", fn () => true)
  structure P : SPEC_INTEGER = Position
  val () = T.check ("Position:INTEGER/matches", fn () => true)
  val () = T.check ("Position:INTEGER/counts-bytes-of-a-file", fn () => P.precision <> SOME 8)
  val () = T.check ("Int:INTEGER/int-is-toplevel", fn () => C.+ (1 : int, 2 : int) = 3)
  val () = T.check ("Int:INTEGER/toplevel-is-int", fn () => (C.fromInt 1 : C.int) + 2 = 3)
end
