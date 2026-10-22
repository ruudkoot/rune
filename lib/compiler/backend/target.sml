(* A target: what it is, and its code from Low. *)
signature TARGET =
sig
  type code
  val info : Target.t
  val program : Low.program -> code
end
