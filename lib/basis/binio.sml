(* BinIO, Byte and Word8Vector. Byte vectors are represented as strings and
   BinIO shares TextIO's stream types. *)
structure Word8Vector =
struct
  type vector = string
  val length = String.size
end

structure Byte =
struct
  fun bytesToString (v : Word8Vector.vector) : string = v
  fun stringToBytes (s : string) : Word8Vector.vector = s
end

structure BinIO =
struct
  type vector = Word8Vector.vector
  type instream = TextIO.instream
  type outstream = TextIO.outstream
  val openIn = TextIO.openIn
  val openOut = TextIO.openOut
  val openAppend = TextIO.openAppend
  val closeIn = TextIO.closeIn
  val closeOut = TextIO.closeOut
  val output = TextIO.output
  val inputAll = TextIO.inputAll
  val flushOut = TextIO.flushOut
end
