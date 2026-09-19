(* requires: PackWord16Big PackWord16Little LargeWord Word8Vector Word8Array *)
(* uses: fn/pack_word_fn.sml *)
(* PackWord16Big and PackWord16Little (signature PACK_WORD): the checks of
   every PACK_WORD structure, from fn/pack_word_fn.sml. *)
structure TestPackWord16 =
struct
  structure Big = TestPackWordFn (structure P = PackWord16Big val name = "PackWord16Big" val bytes = 2 val big = true)
  structure Little = TestPackWordFn (structure P = PackWord16Little val name = "PackWord16Little" val bytes = 2 val big = false)
end
