(* BoolVector: immutable vectors of booleans.

   The family of booleans -- `BoolVector`, `BoolVectorSlice`, `BoolArray`,
   `BoolArraySlice` and `BoolArray2`, all optional in the specification -- is
   in one file: a program that names one of them loads the five. The vector
   is a polymorphic vector underneath, the array a polymorphic array, and
   both are sealed, so that neither is a `bool vector` or a `bool array` for
   a program.

   Implements: MONO_VECTOR where type elem = bool

   Status: optional *)
structure BoolVector :> MONO_VECTOR where type elem = bool = RuneMonoVectorFn (type elem = bool)
(* BoolVectorSlice: stretches of `BoolVector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = BoolVector.vector where
   type elem = bool

   Status: optional *)
structure BoolVectorSlice :> MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool = RuneMonoVectorSliceFn (structure V = BoolVector)
(* BoolArray: mutable arrays of booleans, a type of their own with identity
   equality, whose vectors are those of `BoolVector`.

   Implements: MONO_ARRAY where type vector = BoolVector.vector where type
   elem = bool

   Status: optional *)
structure BoolArray :> MONO_ARRAY where type vector = BoolVector.vector where type elem = bool = RuneMonoArrayFn (structure V = BoolVector)
(* BoolArraySlice: stretches of `BoolArray` arrays, without a copy: an update
   through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = BoolVector.vector where
   type vector_slice = BoolVectorSlice.slice where type array =
   BoolArray.array where type elem = bool

   Status: optional *)
structure BoolArraySlice :> MONO_ARRAY_SLICE where type vector = BoolVector.vector where type vector_slice = BoolVectorSlice.slice where type array = BoolArray.array where type elem = bool = RuneMonoArraySliceFn (structure V = BoolVector structure A = BoolArray structure VS = BoolVectorSlice)
(* BoolArray2: two-dimensional arrays of booleans, whose rows and columns
   are `BoolVector` vectors.

   Implements: MONO_ARRAY2 where type vector = BoolVector.vector where type
   elem = bool

   Status: optional *)
structure BoolArray2 :> MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool = RuneMonoArray2Fn (structure V = BoolVector)
