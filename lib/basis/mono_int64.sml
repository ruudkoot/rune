(* Int64Vector: immutable vectors of 64-bit integers.

   The vectors, arrays, slices and two-dimensional arrays of Int64 (optional
   in the specification). Int64.int is a type of its own, so these are their own
   structures and not those of Int.

   Implements: MONO_VECTOR where type elem = Int64.int

   Status: optional *)
structure Int64Vector :> MONO_VECTOR where type elem = Int64.int = RuneMonoVectorFn (type elem = Int64.int)
(* Int64VectorSlice: stretches of `Int64Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Int64Vector.vector where
   type elem = Int64.int

   Status: optional *)
structure Int64VectorSlice :> MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int = RuneMonoVectorSliceFn (structure V = Int64Vector)
(* Int64Array: mutable arrays of 64-bit integers, a type of their own with
   identity equality, whose vectors are those of `Int64Vector`.

   Implements: MONO_ARRAY where type vector = Int64Vector.vector where type
   elem = Int64.int

   Status: optional *)
structure Int64Array :> MONO_ARRAY where type vector = Int64Vector.vector where type elem = Int64.int = RuneMonoArrayFn (structure V = Int64Vector)
(* Int64ArraySlice: stretches of `Int64Array` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Int64Vector.vector where
   type vector_slice = Int64VectorSlice.slice where type array =
   Int64Array.array where type elem = Int64.int

   Status: optional *)
structure Int64ArraySlice :> MONO_ARRAY_SLICE where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int =
  RuneMonoArraySliceFn (structure V = Int64Vector structure A = Int64Array structure VS = Int64VectorSlice)
(* Int64Array2: two-dimensional arrays of 64-bit integers, whose rows and
   columns are `Int64Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Int64Vector.vector where type
   elem = Int64.int

   Status: optional *)
structure Int64Array2 :> MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int = RuneMonoArray2Fn (structure V = Int64Vector)
