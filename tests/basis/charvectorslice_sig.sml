(* requires: CharVectorSlice CharVector Substring String *)
(* uses: spec-sigs/MONO_VECTOR_SLICE.sml *)
(* CharVectorSlice matches MONO_VECTOR_SLICE, `where type slice =
   Substring.substring where type vector = String.string where type elem =
   char`. *)
structure TestCharVectorSliceSig =
struct
  structure C : SPEC_MONO_VECTOR_SLICE = CharVectorSlice
  structure E : SPEC_MONO_VECTOR_SLICE where type slice = Substring.substring where type vector = String.string where type elem = char = CharVectorSlice
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/slice-is-Substring.substring",
                    fn () => Substring.string (E.slice ("abcd", 1, SOME 2)) = "bc"
                             andalso E.length (Substring.full "abc") = 3)
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/vector-is-String.string",
                    fn () => String.size (E.vector (E.full "abc")) = 3)
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/vector-is-toplevel-string",
                    fn () => (E.vector (E.full ("abc" : string)) : string) = "abc")
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/vector-is-CharVector.vector",
                    fn () => CharVector.length (E.vector (E.full (CharVector.fromList [#"a"]))) = 1)
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/elem-is-char", fn () => (E.sub (E.full "abc", 1) : char) = #"b")
  (* the signature can be implemented opaquely, given elem and vector *)
  structure O :> SPEC_MONO_VECTOR_SLICE where type vector = string where type elem = char = CharVectorSlice
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => O.base (O.subslice (O.full "abcd", 1, NONE)) = ("abcd", 1, 3))
end
