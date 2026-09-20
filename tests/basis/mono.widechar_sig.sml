(* requires: WideCharVector WideCharArray WideChar *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml *)
(* WideCharVector, WideCharArray, WideCharVectorSlice and WideCharArraySlice
   match their signatures, with the constraints of the specification:
     structure WideCharVector :> MONO_VECTOR where type elem = WideChar.char
     structure WideCharArray :> MONO_ARRAY where type vector = WideCharVector.vector
       where type elem = WideChar.char
     structure WideCharVectorSlice :> MONO_VECTOR_SLICE
       where type vector = WideCharVector.vector where type elem = WideChar.char
     structure WideCharArraySlice :> MONO_ARRAY_SLICE
       where type vector = WideCharVector.vector
       where type vector_slice = WideCharVectorSlice.slice
       where type array = WideCharArray.array where type elem = WideChar.char
   and each can be implemented opaquely. The specification has no
   WideCharArray2. *)
structure TestMonoWideCharSig =
struct
  fun x n = WideChar.chr (65 + n)
  fun eq (a : WideChar.char, b) = a = b

  structure V : SPEC_MONO_VECTOR = WideCharVector
  structure VE : SPEC_MONO_VECTOR where type elem = WideChar.char = WideCharVector
  structure VO :> SPEC_MONO_VECTOR where type elem = WideChar.char = WideCharVector
  val () = T.check ("WideCharVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("WideCharVector:MONO_VECTOR/elem-is-WideChar.char", fn () => eq (VE.sub (VE.fromList [x 7], 0) : WideChar.char, x 7))
  val () = T.check ("WideCharVector:MONO_VECTOR/vector-is-WideCharVector.vector",
                    fn () => WideCharVector.length (V.fromList [] : WideCharVector.vector) = 0 andalso V.length (WideCharVector.fromList [] : V.vector) = 0)
  val () = T.check ("WideCharVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = WideCharArray
  structure AE : SPEC_MONO_ARRAY where type vector = WideCharVector.vector where type elem = WideChar.char = WideCharArray
  structure AO :> SPEC_MONO_ARRAY where type vector = WideCharVector.vector where type elem = WideChar.char = WideCharArray
  val () = T.check ("WideCharArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("WideCharArray:MONO_ARRAY/elem-is-WideChar.char", fn () => eq (AE.sub (AE.array (1, x 7), 0) : WideChar.char, x 7))
  val () = T.check ("WideCharArray:MONO_ARRAY/vector-is-WideCharVector.vector", fn () => WideCharVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("WideCharArray:MONO_ARRAY/array-is-WideCharArray.array",
                    fn () => WideCharArray.length (A.fromList [] : WideCharArray.array) = 0 andalso A.length (WideCharArray.fromList [] : A.array) = 0)
  val () = T.check ("WideCharArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("WideCharArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = WideCharVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = WideCharVector.vector where type elem = WideChar.char = WideCharVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = WideCharVector.vector where type elem = WideChar.char = WideCharVectorSlice
  val () = T.check ("WideCharVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("WideCharVectorSlice:MONO_VECTOR_SLICE/vector-is-WideCharVector.vector",
                    fn () => WideCharVector.length (VSE.vector (VSE.full (WideCharVector.tabulate (3, x)))) = 3)
  val () = T.check ("WideCharVectorSlice:MONO_VECTOR_SLICE/elem-is-WideChar.char",
                    fn () => eq (VSE.sub (VSE.full (WideCharVector.tabulate (3, x)), 2) : WideChar.char, x 2))
  val () = T.check ("WideCharVectorSlice:MONO_VECTOR_SLICE/slice-is-WideCharVectorSlice.slice",
                    fn () => WideCharVectorSlice.length (VS.full (WideCharVector.fromList []) : WideCharVectorSlice.slice) = 0
                             andalso VS.length (WideCharVectorSlice.full (WideCharVector.fromList []) : VS.slice) = 0)
  val () = T.check ("WideCharVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (WideCharVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = WideCharArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = WideCharVector.vector where type vector_slice = WideCharVectorSlice.slice where type array = WideCharArray.array where type elem = WideChar.char = WideCharArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = WideCharVector.vector where type vector_slice = WideCharVectorSlice.slice where type array = WideCharArray.array where type elem = WideChar.char = WideCharArraySlice
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/array-is-WideCharArray.array",
                    fn () => WideCharArray.length (#1 (ASE.base (ASE.full (WideCharArray.array (3, x 0))))) = 3)
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/vector-is-WideCharVector.vector",
                    fn () => WideCharVector.length (ASE.vector (ASE.full (WideCharArray.array (3, x 0)))) = 3)
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/vector_slice-is-WideCharVectorSlice.slice",
                    fn () => let val a = WideCharArray.array (3, x 0)
                             in ASE.copyVec {src = WideCharVectorSlice.full (WideCharVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (WideCharArray.sub (a, 2), x 9) end)
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/elem-is-WideChar.char", fn () => eq (ASE.sub (ASE.full (WideCharArray.array (1, x 7)), 0) : WideChar.char, x 7))
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/slice-is-WideCharArraySlice.slice",
                    fn () => WideCharArraySlice.length (AS.full (WideCharArray.fromList []) : WideCharArraySlice.slice) = 0
                             andalso AS.length (WideCharArraySlice.full (WideCharArray.fromList []) : AS.slice) = 0)
  val () = T.check ("WideCharArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (WideCharArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

end
