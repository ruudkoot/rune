(* The monomorphic vectors and arrays of Real32.real, their slices and the
   two-dimensional arrays (optional in the specification). *)
structure Real32Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Real32.real)
structure Real32VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Real32Vector)
structure Real32Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Real32Vector)
structure Real32ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Real32Vector structure A = Real32Array structure VS = Real32VectorSlice)
structure Real32Array2 = RuneMonoArray2Fn (structure V = Real32Vector)
