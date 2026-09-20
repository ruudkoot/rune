(* requires: PackReal64Big PackReal64Little Word8Vector Word8Array *)
(* uses: fn/pack_real_fn.sml *)
(* PackReal64Big and PackReal64Little (signature PACK_REAL): the checks of every
   PACK_REAL structure of 64-bit reals, from fn/pack_real_fn.sml. *)
structure TestPackReal64 =
struct
  structure Big = TestPackRealFn (structure P = PackReal64Big val name = "PackReal64Big" val big = true)
  structure Little = TestPackRealFn (structure P = PackReal64Little val name = "PackReal64Little" val big = false)
end
