(* requires: PackWord64Big PackWord64Little LargeWord Word8Vector Word8Array *)
(* uses: spec-sigs/PACK_WORD.sml *)
(* PackWord64Big and PackWord64Little match PACK_WORD. *)
structure TestPackWord64Sig =
struct
  structure B : SPEC_PACK_WORD = PackWord64Big
  structure L : SPEC_PACK_WORD = PackWord64Little
  val () = T.check ("PackWord64Big:PACK_WORD/matches", fn () => true)
  val () = T.check ("PackWord64Little:PACK_WORD/matches", fn () => true)
end
