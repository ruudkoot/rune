(* What a program sees of the structures of chararray2.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure CharArray2 : MONO_ARRAY2 where type vector = CharVector.vector where type elem = char = CharArray2
