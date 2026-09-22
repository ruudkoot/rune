(* What a program sees of the structures of mono_real64.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Real64Array : MONO_ARRAY where type vector = Real64Vector.vector where type elem = Real64.real = Real64Array
structure Real64Array2 : MONO_ARRAY2 where type vector = Real64Vector.vector where type elem = Real64.real = Real64Array2
structure Real64ArraySlice : MONO_ARRAY_SLICE where type vector = Real64Vector.vector where type vector_slice = Real64VectorSlice.slice where type array = Real64Array.array where type elem = Real64.real = Real64ArraySlice
structure Real64Vector : MONO_VECTOR where type elem = Real64.real = Real64Vector
structure Real64VectorSlice : MONO_VECTOR_SLICE where type vector = Real64Vector.vector where type elem = Real64.real = Real64VectorSlice
