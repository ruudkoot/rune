(* requires: PackRealBig PackRealLittle Word8Vector Word8Array *)
(* uses: fn/pack_real_fn.sml *)
(* PackRealBig and PackRealLittle (signature PACK_REAL): the checks of every
   PACK_REAL structure of 64-bit reals, from fn/pack_real_fn.sml. *)
structure TestPackReal =
struct
  structure Big = TestPackRealFn (structure P = PackRealBig val name = "PackRealBig" val big = true)
  structure Little = TestPackRealFn (structure P = PackRealLittle val name = "PackRealLittle" val big = false)
end
