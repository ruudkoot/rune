(* input1 to the end of a file, then the file grows, then input1 twice more. *)
fun show NONE = "NONE" | show (SOME c) = "SOME #\"" ^ Char.toString c ^ "\""
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
fun append (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
fun report (what, results) = print (what ^ ": " ^ String.concatWith ", " (map show results) ^ "\n")

(* TextIO.input1 on a stream that TextIO.openIn made *)
val () = write ("a.txt", "a")
val ins = TextIO.openIn "a.txt"
val r1 = TextIO.input1 ins
val r2 = TextIO.input1 ins
val () = append ("a.txt", "z")
val r3 = TextIO.input1 ins
val r4 = TextIO.input1 ins
val () = report ("TextIO.input1, openIn    ", [r1, r2, r3, r4])

(* BinIO.input1 (the bytes shown as characters) *)
val () = write ("b.bin", "a")
val ins = BinIO.openIn "b.bin"
val r1 = BinIO.input1 ins
val r2 = BinIO.input1 ins
val () = append ("b.bin", "z")
val r3 = BinIO.input1 ins
val r4 = BinIO.input1 ins
val () = report ("BinIO.input1, openIn     ", map (Option.map Byte.byteToChar) [r1, r2, r3, r4])

(* for contrast: the same file through TextIO.mkInstream of its StreamIO stream *)
val () = write ("c.txt", "a")
val ins = TextIO.mkInstream (TextIO.getInstream (TextIO.openIn "c.txt"))
val r1 = TextIO.input1 ins
val r2 = TextIO.input1 ins
val () = append ("c.txt", "z")
val r3 = TextIO.input1 ins
val r4 = TextIO.input1 ins
val () = report ("TextIO.input1, mkInstream", [r1, r2, r3, r4])
