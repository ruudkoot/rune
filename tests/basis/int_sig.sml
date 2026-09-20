(* requires: Int LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int matches INTEGER, and Int.int is the top-level int. *)
structure TestIntSig =
struct
  structure C : SPEC_INTEGER = Int
  val () = T.check ("Int:INTEGER/matches", fn () => true)
  val () = T.check ("Int:INTEGER/int-is-toplevel", fn () => C.+ (1 : int, 2 : int) = 3)
  val () = T.check ("Int:INTEGER/toplevel-is-int", fn () => (C.fromInt 1 : C.int) + 2 = 3)
end
