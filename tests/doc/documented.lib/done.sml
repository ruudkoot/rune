(* A signature that is documented in full.

   Area: Tests *)
signature DONE =
sig
  (* The type of counters. *)
  type t

  (* The colours.

     The comment above the first constructor stands before its equals sign. *)
  datatype colour
      (* the first *)
    = Red
      (* the second *)
    | Green

  (* `next c` is the counter after `c`. *)
  val next : t -> t

  (* `up c` and `down c` move a counter by one. *)
  val up : t -> t
  val down : t -> t

  (* The first counter; a constant needs no usage. *)
  val zero : t
end

(* Implements: DONE *)
structure Done = struct type t = int datatype colour = Red | Green fun next c = c + 1 val up = next fun down c = c - 1 val zero = 0 end
