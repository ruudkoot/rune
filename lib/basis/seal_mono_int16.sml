(* What a program sees of the structures of mono_int16.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Int16Array2 : MONO_ARRAY2 where type vector = Int16Vector.vector where type elem = Int16.int = Int16Array2
