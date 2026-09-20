(* Claims: what a structure says it implements, and the notes of its body. *)
signature COUNTER =
sig
  type t
  val zero : t
  val next : t -> t
  structure Limits : sig val max : int end
end

(* A counter of machine integers.

   Implements: COUNTER where type t = int

   Status: optional *)
structure Counter =
struct
  type t = int

  (* Implementation: `Counter.zero/value`. 0. *)
  val zero = 0

  (* Overflow is not caught: an ordinary comment, which is nobody's business.

     Limitation: `Counter.next/overflow`. Raises Overflow at the largest int.

     Pinned by: `Counter.next/Overflow` *)
  fun next n = n + 1

  (* not a note, so not documentation *)
  fun helper n = n

  (* The limits of this counter.

     Implements: LIMITS *)
  structure Limits = struct val max = 100 end

  local
    val hidden = 1
  in
    (* Deviation: `Counter.extra/beyond`. Not in COUNTER. *)
    val extra = hidden
  end
end

(* Implements: COUNTER *)
functor CounterFn (val start : int) =
struct
  type t = int
  (* Implementation: `COUNTER.zero/start`. The start given. *)
  val zero = start
  fun next n = n + 1
  structure Limits = struct val max = 100 end
end

structure Sealed :> COUNTER = Counter
structure FromFunctor = CounterFn (val start = 1)
