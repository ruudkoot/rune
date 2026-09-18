(* BinIO round trip; byte vectors are strings. *)
val path = "tests/out/basis.binio_bytes.tmp"
val out = BinIO.openOut path
val () = BinIO.output (out, Byte.stringToBytes "\000\001\255abc")
val () = BinIO.closeOut out
val ins = BinIO.openIn path
val v = BinIO.inputAll ins
val () = BinIO.closeIn ins
val () = print (Int.toString (Word8Vector.length v) ^ "\n")
val () = print (String.concatWith "," (List.map (Int.toString o Char.ord) (String.explode (Byte.bytesToString v))) ^ "\n")
