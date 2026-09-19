(* The monomorphic vectors and arrays of Int32.int, their slices and the
   two-dimensional arrays (optional in the specification). *)
structure Int32Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Int32.int)
structure Int32VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Int32Vector)
structure Int32Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Int32Vector)
structure Int32ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Int32Vector structure A = Int32Array structure VS = Int32VectorSlice)
structure Int32Array2 = RuneMonoArray2Fn (structure V = Int32Vector)
