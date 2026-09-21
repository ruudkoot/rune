(* What a program sees of the structures of mono_word64.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Word64Array : MONO_ARRAY where type vector = Word64Vector.vector where type elem = Word64.word = Word64Array
structure Word64Array2 : MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word = Word64Array2
structure Word64ArraySlice : MONO_ARRAY_SLICE where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word = Word64ArraySlice
structure Word64Vector : MONO_VECTOR where type elem = Word64.word = Word64Vector
structure Word64VectorSlice : MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word = Word64VectorSlice
