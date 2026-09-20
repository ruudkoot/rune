(* requires: PackWord64Big PackWord64Little LargeWord Word8Vector Word8Array *)
(* uses: fn/pack_word_fn.sml *)
(* PackWord64Big and PackWord64Little (signature PACK_WORD): the checks of
   every PACK_WORD structure, from fn/pack_word_fn.sml. *)
structure TestPackWord64 =
struct
  structure Big = TestPackWordFn (structure P = PackWord64Big val name = "PackWord64Big" val bytes = 8 val big = true)
  structure Little = TestPackWordFn (structure P = PackWord64Little val name = "PackWord64Little" val bytes = 8 val big = false)
end
