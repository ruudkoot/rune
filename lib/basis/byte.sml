(* Byte: between bytes and characters. A Word8Vector.vector is a string, so
   the conversions of whole vectors cost nothing.

   Implements: BYTE *)
structure Byte =
struct
  fun byteToChar (b : Word8.word) : char = chr (Word8.toInt b)
  fun charToByte (c : char) : Word8.word = Word8.fromInt (ord c)
  val bytesToString : Word8Vector.vector -> string = Word8Vector.toString
  val stringToBytes : string -> Word8Vector.vector = Word8Vector.fromString
  fun unpackStringVec (sl : Word8VectorSlice.slice) : string = Word8Vector.toString (Word8VectorSlice.vector sl)
  fun unpackString (sl : Word8ArraySlice.slice) : string = Word8Vector.toString (Word8ArraySlice.vector sl)
  (* "raises Subscript if i < 0 or size s + i > |arr|" *)
  fun packString (arr : Word8Array.array, i : int, ss : substring) : unit =
    if i < 0 orelse i > Word8Array.length arr - Substring.size ss then raise Subscript
    else Substring.app (let val k = ref i in fn c => (Word8Array.update (arr, !k, charToByte c); k := !k + 1) end) ss
end
