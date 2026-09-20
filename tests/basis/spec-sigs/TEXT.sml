(* signature TEXT, transcribed from https://smlfamily.github.io/Basis/text.html

   The signatures of the substructures are those of tests/basis/spec-sigs:
   CHAR.sml, STRING.sml, SUBSTRING.sml, MONO_VECTOR.sml, MONO_ARRAY.sml,
   MONO_VECTOR_SLICE.sml and MONO_ARRAY_SLICE.sml. The constraints of
   `structure Text :> TEXT where type Char.char = Char.char ...` are in
   tests/basis/text_sig.sml. *)
signature SPEC_TEXT =
sig
  structure Char : SPEC_CHAR
  structure String : SPEC_STRING
  structure Substring : SPEC_SUBSTRING
  structure CharVector : SPEC_MONO_VECTOR
  structure CharArray : SPEC_MONO_ARRAY
  structure CharVectorSlice : SPEC_MONO_VECTOR_SLICE
  structure CharArraySlice : SPEC_MONO_ARRAY_SLICE
  sharing type Char.char = String.char = Substring.char
    = CharVector.elem = CharArray.elem = CharVectorSlice.elem
    = CharArraySlice.elem
  sharing type Char.string = String.string = Substring.string
    = CharVector.vector = CharArray.vector
    = CharVectorSlice.vector = CharArraySlice.vector
  sharing type CharArray.array = CharArraySlice.array
  sharing type CharVectorSlice.slice
    = CharArraySlice.vector_slice
end
