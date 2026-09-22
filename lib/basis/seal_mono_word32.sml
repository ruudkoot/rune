(* What a program sees of the structures of mono_word32.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Word32Array2 : MONO_ARRAY2 where type vector = Word32Vector.vector where type elem = Word32.word = Word32Array2
