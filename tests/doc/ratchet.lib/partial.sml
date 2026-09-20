(* A signature that the ratchet list names too early. *)
signature PARTIAL =
sig
  type t

  (* Moves a counter, and says so without showing how it is called. *)
  val move : t -> t

  (* `far c` is a function whose first paragraph goes on and on, well beyond what an index page can show as a summary, because it says everything there is to say about the function in one breath, which a second paragraph should do. *)
  val far : t -> t

  (* A reader of counters. *)
  type 'a reader = 'a -> (t * 'a) list

  (* `scan strm` reads a counter: one argument, as the expanded type has it. *)
  val scan : int reader

  (* `scan2 strm more` has an argument that the expanded type does not have. *)
  val scan2 : int reader

  (* `fail c` raises.

     Raises: `Nothing` whenever it is called. *)
  val fail : t -> t

  (* `lost c` refers to `Done.next`, which is there, and to `Done.nothing` and `Nowhere.at`, which are not. *)
  val lost : t -> t
end

(* Implements: PARTIAL *)
structure Partial =
struct
  type t = int
  type 'a reader = 'a -> (t * 'a) list
  fun move c = c
  fun far c = c
  fun scan (strm : int) = [(0, strm)]
  val scan2 = scan
  fun fail (c : t) : t = raise Match
  fun lost c = c
end
