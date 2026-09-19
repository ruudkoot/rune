(* requires: PackReal64Big PackReal64Little Word8Vector Word8Array *)
(* uses: spec-sigs/PACK_REAL.sml *)
(* PackReal64Big and PackReal64Little match PACK_REAL "where type real = Real64.real". *)
structure TestPackReal64Sig =
struct
  structure B : SPEC_PACK_REAL where type real = Real64.real = PackReal64Big
  structure L : SPEC_PACK_REAL where type real = Real64.real = PackReal64Little
  val () = T.check ("PackReal64Big:PACK_REAL/matches", fn () => true)
  val () = T.check ("PackReal64Little:PACK_REAL/matches", fn () => true)
end
