(* Counters. *)
signature COUNTER =
sig
  type t
  val zero : t
  val next : t -> t
end

(* Implements: COUNTER where type t = int *)
structure Good =
struct
  type t = int

  (* Implementation: `Good.zero/is-zero`. Zero; its check pins the note.

     Implementation: `Good.zero/value`. Pinned by checks that exist, and by one that does not.

     Pinned by: `Good.zero/again-*`, `Good.zero/no-such-check`

     Deviation: `Good.zero/is-zero`. The same id again. *)
  val zero = 0
  fun next c = c + 1
end

(* Its next has the wrong type.

   Implements: COUNTER *)
structure Wrong = struct type t = int val zero = 0 fun next (c : t) = "next" end

(* Its t is not the type the claim says.

   Implements: COUNTER where type t = string *)
structure Narrow = struct type t = int val zero = 0 fun next c = c + 1 end

(* It has no zero.

   Implements: COUNTER *)
structure Missing = struct type t = int fun next c = c + 1 end

(* An ascription is a claim too, and the compiler has checked it already. *)
structure Sealed :> COUNTER = Good
