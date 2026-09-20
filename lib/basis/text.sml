(* Text: the structures of the default character type.

   Implements: TEXT where type Char.char = Char.char where type String.string
   = String.string where type Substring.substring = Substring.substring where
   type CharArray.array = CharArray.array where type CharVectorSlice.slice =
   CharVectorSlice.slice where type CharArraySlice.slice =
   CharArraySlice.slice *)
structure Text =
struct
  structure Char = Char
  structure String = String
  structure Substring = Substring
  structure CharVector = CharVector
  structure CharArray = CharArray
  structure CharVectorSlice = CharVectorSlice
  structure CharArraySlice = CharArraySlice
end
