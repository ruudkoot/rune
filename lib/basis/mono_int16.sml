(* The monomorphic vectors and arrays of Int16.int, their slices and the
   two-dimensional arrays (optional in the specification). *)
structure Int16Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Int16.int)
structure Int16VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Int16Vector)
structure Int16Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Int16Vector)
structure Int16ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Int16Vector structure A = Int16Array structure VS = Int16VectorSlice)
structure Int16Array2 = RuneMonoArray2Fn (structure V = Int16Vector)
