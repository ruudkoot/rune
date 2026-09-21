(* The vectors, arrays, slices and two-dimensional arrays of Int64 (optional
   in the specification). Int64.int is a type of its own, so these are their own
   structures and not those of Int.

   Implements: MONO_VECTOR where type elem = Int64.int

   Status: optional *)
structure Int64Vector :> MONO_VECTOR where type elem = Int64.int = RuneMonoVectorFn (type elem = Int64.int)
(* Implements: MONO_VECTOR_SLICE where type vector = Int64Vector.vector where
   type elem = Int64.int

   Status: optional *)
structure Int64VectorSlice :> MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int = RuneMonoVectorSliceFn (structure V = Int64Vector)
(* Implements: MONO_ARRAY where type vector = Int64Vector.vector where type
   elem = Int64.int

   Status: optional *)
structure Int64Array :> MONO_ARRAY where type vector = Int64Vector.vector where type elem = Int64.int = RuneMonoArrayFn (structure V = Int64Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Int64Vector.vector where
   type vector_slice = Int64VectorSlice.slice where type array =
   Int64Array.array where type elem = Int64.int

   Status: optional *)
structure Int64ArraySlice :> MONO_ARRAY_SLICE where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int =
  RuneMonoArraySliceFn (structure V = Int64Vector structure A = Int64Array structure VS = Int64VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Int64Vector.vector where type
   elem = Int64.int

   Status: optional *)
structure Int64Array2 :> MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int = RuneMonoArray2Fn (structure V = Int64Vector)
