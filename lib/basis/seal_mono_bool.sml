(* What a program sees of the structures of mono_bool.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure BoolArray2 : MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool = BoolArray2
