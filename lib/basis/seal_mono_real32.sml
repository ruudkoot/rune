(* What a program sees of the structures of mono_real32.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Real32Array2 : MONO_ARRAY2 where type vector = Real32Vector.vector where type elem = Real32.real = Real32Array2
