(* requires: PackWord32Big PackWord32Little LargeWord Word8Vector Word8Array *)
(* uses: fn/pack_word_fn.sml *)
(* PackWord32Big and PackWord32Little (signature PACK_WORD): the checks of
   every PACK_WORD structure, from fn/pack_word_fn.sml. *)
structure TestPackWord32 =
struct
  structure Big = TestPackWordFn (structure P = PackWord32Big val name = "PackWord32Big" val bytes = 4 val big = true)
  structure Little = TestPackWordFn (structure P = PackWord32Little val name = "PackWord32Little" val bytes = 4 val big = false)
end
