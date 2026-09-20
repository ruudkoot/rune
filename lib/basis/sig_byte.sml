(* Between bytes and characters: the same eight bits read as a `Word8.word`
   and as a `char`.

   The conversions are of the codes, not of any encoding: the byte 200 is the
   character whose code is 200, whatever a locale would make of it. Text that
   comes in as bytes (from `BinIO`, a socket, `Word8Array`) becomes a string
   here, and the other way round.

   Area: Text and characters

   See also: `CHAR`, `STRING`, `SUBSTRING`, `MONO_VECTOR`

   Implementation: `Byte/free`. A `Word8Vector.vector` is a `string` in this
   library, so `bytesToString` and `stringToBytes` copy nothing. *)
signature BYTE =
sig
  (* `byteToChar b` is the character whose code is `b`.

     Reading: `Byte.byteToChar/high-bytes-are-not-negative`. A byte is an
     unsigned number: 200 is the character with code 200, and not the one
     that a signed byte of ~56 would name.

     Law: `Char.ord (byteToChar b) = Word8.toInt b`

     Example: `byteToChar 0w65 = #"A"` *)
  val byteToChar : Word8.word -> char

  (* `charToByte c` is the code of `c` as a byte.

     Law: `charToByte (byteToChar b) = b`

     Example: `charToByte #"a" = 0w97` *)
  val charToByte : char -> Word8.word

  (* `bytesToString v` is the string of the characters whose codes are the bytes of `v`, in order.

     Example: `bytesToString (stringToBytes "hi") = "hi"` *)
  val bytesToString : Word8Vector.vector -> string

  (* `stringToBytes s` is the vector of the codes of the characters of `s`, in order.

     Law: `bytesToString (stringToBytes s) = s` *)
  val stringToBytes : string -> Word8Vector.vector

  (* `unpackStringVec sl` is the string of the bytes of the vector slice `sl`.

     Example: `unpackStringVec (Word8VectorSlice.slice (stringToBytes "hello",
     1, SOME 3)) = "ell"` *)
  val unpackStringVec : Word8VectorSlice.slice -> string

  (* `unpackString sl` is the string of the bytes of the array slice `sl`.

     Reading: `Byte.unpackString/sees-the-current-contents`. An array can
     change: the bytes are read when `unpackString` is called, so the string
     holds what the slice had at that moment and is not touched by a later
     update. *)
  val unpackString : Word8ArraySlice.slice -> string

  (* `packString (arr, i, ss)` writes the characters of the substring `ss` into `arr`, from position `i` on.

     Raises: `Subscript` if `i < 0` or if the characters would not fit, that
     is if `i + Substring.size ss > Word8Array.length arr`. *)
  val packString : Word8Array.array * int * substring -> unit
end
