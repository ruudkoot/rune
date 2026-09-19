(* requires: PackWord32Big PackWord32Little LargeWord Word8Vector Word8Array *)
(* uses: spec-sigs/PACK_WORD.sml *)
(* PackWord32Big and PackWord32Little match PACK_WORD. *)
structure TestPackWord32Sig =
struct
  structure B : SPEC_PACK_WORD = PackWord32Big
  structure L : SPEC_PACK_WORD = PackWord32Little
  val () = T.check ("PackWord32Big:PACK_WORD/matches", fn () => true)
  val () = T.check ("PackWord32Little:PACK_WORD/matches", fn () => true)
end
