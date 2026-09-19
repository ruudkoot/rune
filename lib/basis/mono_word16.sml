(* The monomorphic vectors and arrays of Word16.word, their slices and the
   two-dimensional arrays (optional in the specification). *)
structure Word16Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Word16.word)
structure Word16VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Word16Vector)
structure Word16Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Word16Vector)
structure Word16ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Word16Vector structure A = Word16Array structure VS = Word16VectorSlice)
structure Word16Array2 = RuneMonoArray2Fn (structure V = Word16Vector)
