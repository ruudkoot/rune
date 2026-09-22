(* What a program sees of the structures of mono_int64.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure Int64Array : MONO_ARRAY where type vector = Int64Vector.vector where type elem = Int64.int = Int64Array
structure Int64Array2 : MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int = Int64Array2
structure Int64ArraySlice : MONO_ARRAY_SLICE where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int = Int64ArraySlice
structure Int64Vector : MONO_VECTOR where type elem = Int64.int = Int64Vector
structure Int64VectorSlice : MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int = Int64VectorSlice
