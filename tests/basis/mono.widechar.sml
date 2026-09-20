(* requires: WideCharVector WideCharArray WideChar List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml *)
(* WideCharVector, WideCharArray, WideCharVectorSlice and WideCharArraySlice
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE
   and MONO_ARRAY_SLICE "where type elem = WideChar.char"): the checks that
   hold for every structure of those signatures, from fn/mono_*_fn.sml, on 16
   sample characters from all over the code points. WideCharVector.vector is
   the type of WideString. The slices are in a section, for a host that has
   the vectors and arrays alone; the specification has no WideCharArray2. *)
structure TestMonoWideChar =
struct
  val C = WideChar.chr
  val elems = Vector.fromList (List.map C [0, 9, 65, 97, 127, 128, 233, 255,
                                           256, 0x3BB, 0x4E2D, 0xFFFF, 0x10000, 0x1F600, 0x10FFFE, 0x10FFFF])
  val show = WideChar.toString
  fun same (a : WideChar.char, b) = a = b

  structure Vector_ = TestMonoVectorFn (structure V = WideCharVector val name = "WideCharVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = WideCharArray structure V = WideCharVector val name = "WideCharArray" val elems = elems val show = show val same = same)

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = WideCharVectorSlice structure V = WideCharVector val name = "WideCharVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = WideCharArraySlice structure A = WideCharArray structure V = WideCharVector structure VS = WideCharVectorSlice val name = "WideCharArraySlice" val elems = elems val show = show val same = same)
  (*>> slices *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = WideCharVector val name = "WideCharVector" val elem = C 65)
  structure ArraySize = TestMonoArraySizeFn (structure A = WideCharArray val name = "WideCharArray" val elem = C 65)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = WideCharVectorSlice structure V = WideCharVector val name = "WideCharVectorSlice" val elem = C 65)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = WideCharVectorSlice structure V = WideCharVector val name = "WideCharVectorSlice" val elem = C 65)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = WideCharArraySlice structure A = WideCharArray val name = "WideCharArraySlice" val elem = C 65)
  (*>> slices-size *)
end
