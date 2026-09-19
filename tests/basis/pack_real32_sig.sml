(* requires: PackReal32Big PackReal32Little Real32 Word8Vector Word8Array *)
(* uses: spec-sigs/PACK_REAL.sml *)
(* PackReal32Big and PackReal32Little match PACK_REAL "where type real = Real32.real". *)
structure TestPackReal32Sig =
struct
  structure B : SPEC_PACK_REAL where type real = Real32.real = PackReal32Big
  structure L : SPEC_PACK_REAL where type real = Real32.real = PackReal32Little
  val () = T.check ("PackReal32Big:PACK_REAL/matches", fn () => true)
  val () = T.check ("PackReal32Little:PACK_REAL/matches", fn () => true)
end
