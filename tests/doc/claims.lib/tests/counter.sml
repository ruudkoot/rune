(* A little suite in the conventions of tests/basis, for the extractor of
   labels and the coverage check: Good.zero has checks, Good.next has none of
   its own but one through a test functor, Wrong has none at all. *)
structure TestCounter =
struct
  val eqI = T.eq T.int
  val () = eqI ("Good.zero/is-zero", 0, fn () => Good.zero)
  val () = T.raises ("Good.zero/never-raises", T.isOverflow, fn () => Good.zero)
  val () = List.app (fn i => eqI ("Good.zero/again-" ^ Int.toString i, 0, fn () => Good.zero)) [1, 2]
  (* "Good.next/in-a-comment" is no check, and neither is a path: *)
  val path = "a.b/c"
  structure G = TestCounterFn (structure C = Good val name = "Good")
  structure W = TestCounterFn (structure C = Wrong val name = "Wrong")
  val () = T.check ("Good:COUNTER/matches", fn () => true)
end
