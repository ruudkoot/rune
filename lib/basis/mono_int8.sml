(* The monomorphic vectors and arrays of Int8.int, their slices and the
   two-dimensional arrays (optional in the specification). *)
structure Int8Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Int8.int)
structure Int8VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Int8Vector)
structure Int8Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Int8Vector)
structure Int8ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Int8Vector structure A = Int8Array structure VS = Int8VectorSlice)
structure Int8Array2 = RuneMonoArray2Fn (structure V = Int8Vector)
