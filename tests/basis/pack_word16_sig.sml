(* requires: PackWord16Big PackWord16Little LargeWord Word8Vector Word8Array *)
(* uses: spec-sigs/PACK_WORD.sml *)
(* PackWord16Big and PackWord16Little match PACK_WORD. *)
structure TestPackWord16Sig =
struct
  structure B : SPEC_PACK_WORD = PackWord16Big
  structure L : SPEC_PACK_WORD = PackWord16Little
  val () = T.check ("PackWord16Big:PACK_WORD/matches", fn () => true)
  val () = T.check ("PackWord16Little:PACK_WORD/matches", fn () => true)
end
