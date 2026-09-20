(* A signature that the ratchet list names too early. *)
signature PARTIAL =
sig
  type t

  (* Moves a counter, and says so without showing how it is called. *)
  val move : t -> t

  (* `far c` is a function whose first paragraph goes on and on, well beyond what an index page can show as a summary, because it says everything there is to say about the function in one breath, which a second paragraph should do. *)
  val far : t -> t

  (* `lost c` refers to `Done.next`, which is there, and to `Done.nothing` and `Nowhere.at`, which are not. *)
  val lost : t -> t
end

(* Implements: PARTIAL *)
structure Partial = struct type t = int fun move c = c fun far c = c fun lost c = c end
