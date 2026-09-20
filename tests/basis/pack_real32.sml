(* requires: PackReal32Big PackReal32Little Real32 Word8Vector Word8Array *)
(* uses: fn/pack_real32_fn.sml *)
(* PackReal32Big and PackReal32Little (signature PACK_REAL): the checks of
   fn/pack_real32_fn.sml, on the encodings of IEEE 754 binary32. *)
structure TestPackReal32 =
struct
  structure Big = TestPackReal32Fn (structure P = PackReal32Big val name = "PackReal32Big" val big = true)
  structure Little = TestPackReal32Fn (structure P = PackReal32Little val name = "PackReal32Little" val big = false)
end
