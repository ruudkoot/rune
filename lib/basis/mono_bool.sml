(* The monomorphic vectors and arrays of booleans and their slices, and the
   two-dimensional arrays (all optional in the specification), in one file:
   a program that names one of them loads the five. The vector is a
   polymorphic vector (RuneMonoVectorFn), the array a polymorphic array. *)
structure BoolVector : MONO_VECTOR = RuneMonoVectorFn (type elem = bool)
structure BoolVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = BoolVector)
structure BoolArray : MONO_ARRAY = RuneMonoArrayFn (structure V = BoolVector)
structure BoolArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = BoolVector structure A = BoolArray structure VS = BoolVectorSlice)
structure BoolArray2 = RuneMonoArray2Fn (structure V = BoolVector)
