(* The monomorphic vectors and arrays of word, their slices and the
   two-dimensional arrays (optional in the specification). LargeWordVector,
   Word64Vector and the rest of those families are these (mono_largeword.sml,
   mono_word64.sml). *)
structure WordVector : MONO_VECTOR = RuneMonoVectorFn (type elem = word)
structure WordVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = WordVector)
structure WordArray : MONO_ARRAY = RuneMonoArrayFn (structure V = WordVector)
structure WordArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = WordVector structure A = WordArray structure VS = WordVectorSlice)
structure WordArray2 = RuneMonoArray2Fn (structure V = WordVector)
