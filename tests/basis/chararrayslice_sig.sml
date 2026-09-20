(* requires: CharArraySlice CharArray CharVectorSlice CharVector String *)
(* uses: spec-sigs/MONO_ARRAY_SLICE.sml *)
(* CharArraySlice matches MONO_ARRAY_SLICE, `where type vector =
   CharVector.vector where type vector_slice = CharVectorSlice.slice where type
   array = CharArray.array where type elem = char`. *)
structure TestCharArraySliceSig =
struct
  structure C : SPEC_MONO_ARRAY_SLICE = CharArraySlice
  structure E : SPEC_MONO_ARRAY_SLICE where type vector = CharVector.vector where type vector_slice = CharVectorSlice.slice where type array = CharArray.array where type elem = char = CharArraySlice
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/array-is-CharArray.array",
                    fn () => E.length (E.full (CharArray.array (3, #"x"))) = 3
                             andalso CharArray.length (#1 (E.base (E.full (CharArray.array (3, #"x"))))) = 3)
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/vector-is-CharVector.vector",
                    fn () => CharVector.length (E.vector (E.full (CharArray.array (3, #"x")))) = 3)
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/vector-is-string",
                    fn () => (E.vector (E.full (CharArray.array (3, #"x"))) : string) = "xxx")
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/vector_slice-is-CharVectorSlice.slice",
                    fn () => let val a = CharArray.array (3, #"-")
                             in E.copyVec {src = CharVectorSlice.full "ab", dst = a, di = 1}; CharArray.vector a = "-ab" end)
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/elem-is-char", fn () => (E.sub (E.full (CharArray.array (1, #"b")), 0) : char) = #"b")
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/slice-is-CharArraySlice.slice",
                    fn () => CharArraySlice.length (E.full (CharArray.fromList []) : CharArraySlice.slice) = 0)
  (*<< substring *)
  structure U : SPEC_MONO_ARRAY_SLICE where type vector_slice = Substring.substring where type array = CharArray.array = CharArraySlice
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Substring.substring",
                    fn () => let val a = CharArray.array (3, #"-")
                             in U.copyVec {src = Substring.full "ab", dst = a, di = 1}; CharArray.vector a = "-ab" end)
  (*>> substring *)
  (* the signature can be implemented opaquely, given the other types *)
  structure O :> SPEC_MONO_ARRAY_SLICE where type vector = string where type vector_slice = CharVectorSlice.slice where type array = CharArray.array where type elem = char = CharArraySlice
  val () = T.check ("CharArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => O.vector (O.subslice (O.full (CharArray.tabulate (4, fn i => Char.chr (97 + i))), 1, NONE)) = "bcd")
end
