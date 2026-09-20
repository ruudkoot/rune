(* The monomorphic vectors and arrays of Word32.word, their slices and the
   two-dimensional arrays (optional in the specification). *)
structure Word32Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Word32.word)
structure Word32VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Word32Vector)
structure Word32Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Word32Vector)
structure Word32ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Word32Vector structure A = Word32Array structure VS = Word32VectorSlice)
structure Word32Array2 = RuneMonoArray2Fn (structure V = Word32Vector)
