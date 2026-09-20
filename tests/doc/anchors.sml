(* Anchors: symbolic and primed identifiers, members of substructures, and two
   names that GitHub cannot tell apart. *)
signature ANCHORS =
sig
  val @ : 'a list * 'a list -> 'a list
  val := : 'a ref * 'a -> unit
  val socket : unit -> int
  val socket' : int -> int
  val file_desc : int
  structure Ctl : sig val getDEBUG : unit -> bool end

  (* See `socket'`, `Ctl.getDEBUG`, `@` and `ANCHORS`; `Nowhere.at` leads nowhere. *)
  val toString : int -> string
  val tostring : int -> string
end
