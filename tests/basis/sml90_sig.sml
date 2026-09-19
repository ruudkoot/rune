(* requires: SML90 *)
(* uses: spec-sigs/SML90.sml *)
(* SML90 matches SML90. *)
structure TestSML90Sig =
struct
  structure C : SPEC_SML90 = SML90
  val () = T.check ("SML90:SML90/matches", fn () => true)
end
