(* WideText: the structures of the wide character (optional in the
   specification), as Text is of char. *)
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
