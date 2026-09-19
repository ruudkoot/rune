(* requires: PackRealBig PackRealLittle Word8Vector Word8Array *)
(* uses: spec-sigs/PACK_REAL.sml *)
(* PackRealBig and PackRealLittle match PACK_REAL "where type real = Real.real". *)
structure TestPackRealSig =
struct
  structure B : SPEC_PACK_REAL where type real = Real.real = PackRealBig
  structure L : SPEC_PACK_REAL where type real = Real.real = PackRealLittle
  val () = T.check ("PackRealBig:PACK_REAL/matches", fn () => true)
  val () = T.check ("PackRealLittle:PACK_REAL/matches", fn () => true)
end
