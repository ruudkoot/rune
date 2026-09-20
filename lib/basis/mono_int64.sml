(* Int64 is Int, so its vectors, arrays, slices and two-dimensional arrays
   (optional in the specification) are those of Int.

   Implements: MONO_VECTOR where type elem = Int64.int

   Status: optional *)
structure Int64Vector = IntVector
(* Implements: MONO_VECTOR_SLICE where type vector = Int64Vector.vector where
   type elem = Int64.int

   Status: optional *)
structure Int64VectorSlice = IntVectorSlice
(* Implements: MONO_ARRAY where type vector = Int64Vector.vector where type
   elem = Int64.int

   Status: optional *)
structure Int64Array = IntArray
(* Implements: MONO_ARRAY_SLICE where type vector = Int64Vector.vector where
   type vector_slice = Int64VectorSlice.slice where type array =
   Int64Array.array where type elem = Int64.int

   Status: optional *)
structure Int64ArraySlice = IntArraySlice
(* Implements: MONO_ARRAY2 where type vector = Int64Vector.vector where type
   elem = Int64.int

   Status: optional *)
structure Int64Array2 = IntArray2
