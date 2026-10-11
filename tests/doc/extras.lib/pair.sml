(* Pairs.

   Area: Tests *)
signature PAIR =
sig
  (* The first of two. *)
  val first : int
end

functor RunePairFn (val n : int) =
struct
  val first = n
  val second = n + 1
end

(* Implements: PAIR *)
structure Pair = RunePairFn (val n = 1)

(* Implements: PAIR *)
structure Twin = Pair
