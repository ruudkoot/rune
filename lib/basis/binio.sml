(* BinIO: binary files. A Word8Vector.vector is a string, and BinIO shares
   TextIO's stream types. *)
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
