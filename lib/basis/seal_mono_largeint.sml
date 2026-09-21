(* What a program sees of the structures of mono_largeint.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure LargeIntArray2 : MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntArray2
