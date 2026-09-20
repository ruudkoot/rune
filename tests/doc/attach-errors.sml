(* Comments that document nothing, in a signature: each is an error. *)
signature LOST =
sig
  val f : (int -> int) (* after an argument *) -> int

  (* the first of two comments above one item *)
  (* the second *)
  val g : int

  datatype t = (* after the equals sign *) A | B

  structure S : ORD
    (* above a keyword that begins nothing documentable *)
    where type t = int
end
