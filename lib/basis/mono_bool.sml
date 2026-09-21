(* The monomorphic vectors and arrays of booleans and their slices, and the
   two-dimensional arrays (all optional in the specification), in one file:
   a program that names one of them loads the five. The vector is a
   polymorphic vector (RuneMonoVectorFn), the array a polymorphic array.

   Implements: MONO_VECTOR where type elem = bool

   Status: optional *)
structure BoolVector :> MONO_VECTOR where type elem = bool = RuneMonoVectorFn (type elem = bool)
(* Implements: MONO_VECTOR_SLICE where type vector = BoolVector.vector where
   type elem = bool

   Status: optional *)
structure BoolVectorSlice :> MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool = RuneMonoVectorSliceFn (structure V = BoolVector)
(* Implements: MONO_ARRAY where type vector = BoolVector.vector where type
   elem = bool

   Status: optional *)
structure BoolArray :> MONO_ARRAY where type vector = BoolVector.vector where type elem = bool = RuneMonoArrayFn (structure V = BoolVector)
(* Implements: MONO_ARRAY_SLICE where type vector = BoolVector.vector where
   type vector_slice = BoolVectorSlice.slice where type array =
   BoolArray.array where type elem = bool

   Status: optional *)
structure BoolArraySlice :> MONO_ARRAY_SLICE where type vector = BoolVector.vector where type vector_slice = BoolVectorSlice.slice where type array = BoolArray.array where type elem = bool = RuneMonoArraySliceFn (structure V = BoolVector structure A = BoolArray structure VS = BoolVectorSlice)
(* Implements: MONO_ARRAY2 where type vector = BoolVector.vector where type
   elem = bool

   Status: optional *)
structure BoolArray2 :> MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool = RuneMonoArray2Fn (structure V = BoolVector)
