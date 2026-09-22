(* WideText: the structures of the wide character (optional in the
   specification), as Text is of char.

   Implements: TEXT where type Char.char = WideChar.char where type
   String.string = WideString.string where type Substring.substring =
   WideSubstring.substring where type CharArray.array = WideCharArray.array
   where type CharVectorSlice.slice = WideCharVectorSlice.slice where type
   CharArraySlice.slice = WideCharArraySlice.slice

   Status: optional *)
structure WideText =
struct
  structure Char = WideChar
  structure String = WideString
  structure Substring = WideSubstring
  structure CharVector = WideCharVector
  structure CharArray = WideCharArray
  structure CharVectorSlice = WideCharVectorSlice
  structure CharArraySlice = WideCharArraySlice
end
