(* The structures of one kind of text, gathered so that their types can be
   named as one: characters, strings, substrings and the vectors and arrays
   of characters, with the constraints that tie them together.

   `Text` is the text of 8-bit characters, whose `Text.Char` is `Char` and
   whose `Text.String` is `String`; the optional `WideText` is the same for
   `WideChar`. A program that is to work at either kind takes the structure as
   a functor argument and names the types through it.

   Area: Text and characters

   See also: `CHAR`, `STRING`, `SUBSTRING`, `MONO_VECTOR`, `MONO_ARRAY` *)
signature TEXT =
sig
  (* The characters: `Char` for `Text`, `WideChar` for `WideText`. *)
  structure Char : CHAR

  (* The strings of those characters. *)
  structure String : STRING

  (* Their substrings. *)
  structure Substring : SUBSTRING

  (* Their strings seen as immutable sequences. *)
  structure CharVector : MONO_VECTOR

  (* Mutable sequences of those characters. *)
  structure CharArray : MONO_ARRAY

  (* Slices of the vectors: the substrings, under their sequence interface. *)
  structure CharVectorSlice : MONO_VECTOR_SLICE

  (* Slices of the arrays. *)
  structure CharArraySlice : MONO_ARRAY_SLICE

  (* The element type of all of them is one type: the character.

     Erratum: `TEXT/vector-constraint`. The specification writes the identity
     of `CharVector.vector` with `String.string` as one more `sharing`
     constraint. It cannot be written after the constraint on `String.string`
     itself (Definition, rule 64: the type is no longer flexible), so it is
     checked on values in the suite instead.

     Pinned by: `Text:TEXT/CharVector.vector` *)
  sharing type Char.char = String.char = Substring.char
    = CharVector.elem = CharArray.elem = CharVectorSlice.elem
    = CharArraySlice.elem

  (* And the sequence type of all of them is the string. *)
  sharing type Char.string = String.string = Substring.string
    = CharVector.vector = CharArray.vector
    = CharVectorSlice.vector = CharArraySlice.vector

  (* An array and the slices of arrays are of one type. *)
  sharing type CharArray.array = CharArraySlice.array

  (* And a slice of a vector is what an array slice gives when it is copied out. *)
  sharing type CharVectorSlice.slice
    = CharArraySlice.vector_slice
end
