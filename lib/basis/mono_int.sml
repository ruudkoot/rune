(* The monomorphic vectors and arrays of int, their slices and the
   two-dimensional arrays (optional in the specification). Int64Vector and the
   rest of that family are these (mono_int64.sml). *)
structure IntVector : MONO_VECTOR = RuneMonoVectorFn (type elem = int)
structure IntVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = IntVector)
structure IntArray : MONO_ARRAY = RuneMonoArrayFn (structure V = IntVector)
structure IntArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = IntVector structure A = IntArray structure VS = IntVectorSlice)
structure IntArray2 = RuneMonoArray2Fn (structure V = IntVector)
