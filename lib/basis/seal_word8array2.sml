(* What a program sees of the structures of word8array2.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Word8Array2 : MONO_ARRAY2 where type vector = Word8Vector.vector where type elem = Word8.word = Word8Array2
