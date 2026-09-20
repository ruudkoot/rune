(* requires: List *)
(* uses: spec-sigs/LIST.sml *)
(* List matches LIST, and its types are the top-level ones. *)
structure TestListSig =
struct
  structure C : SPEC_LIST = List
  val () = T.check ("List:LIST/matches", fn () => true)
  val () = T.check ("List:LIST/list-is-toplevel", fn () => C.length ([1, 2] : int list) = 2)
  val () = T.check ("List:LIST/toplevel-is-list", fn () => length (C.:: (1, C.nil) : int C.list) = 1)
end
