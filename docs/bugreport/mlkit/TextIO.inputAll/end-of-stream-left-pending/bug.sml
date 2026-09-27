(* inputAll, then the file grows, then inputAll twice more. *)
fun show s = "\"" ^ String.toString s ^ "\""
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
fun append (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
fun report (what, results) = print (what ^ ": " ^ String.concatWith ", " (map show results) ^ "\n")

(* TextIO.inputAll on a file *)
val () = write ("a.txt", "abc")
val ins = TextIO.openIn "a.txt"
val r1 = TextIO.inputAll ins
val () = append ("a.txt", "defg")
val r2 = TextIO.inputAll ins
val r3 = TextIO.inputAll ins
val () = report ("TextIO.inputAll          ", [r1, r2, r3])

(* BinIO.inputAll on a file (the bytes shown as characters) *)
val () = write ("b.bin", "abc")
val ins = BinIO.openIn "b.bin"
val r1 = Byte.bytesToString (BinIO.inputAll ins)
val () = append ("b.bin", "defg")
val r2 = Byte.bytesToString (BinIO.inputAll ins)
val r3 = Byte.bytesToString (BinIO.inputAll ins)
val () = report ("BinIO.inputAll           ", [r1, r2, r3])

(* TextIO.inputN (ins, 5) on a file: fewer than 5 characters each time *)
val () = write ("c.txt", "ab")
val ins = TextIO.openIn "c.txt"
val r1 = TextIO.inputN (ins, 5)
val () = append ("c.txt", "cd")
val r2 = TextIO.inputN (ins, 5)
val r3 = TextIO.inputN (ins, 5)
val () = report ("TextIO.inputN            ", [r1, r2, r3])

(* for contrast: TextIO.StreamIO.inputAll on the same kind of file *)
val () = write ("d.txt", "abc")
val f = TextIO.getInstream (TextIO.openIn "d.txt")
val (r1, f) = TextIO.StreamIO.inputAll f
val () = append ("d.txt", "defg")
val (r2, f) = TextIO.StreamIO.inputAll f
val (r3, _) = TextIO.StreamIO.inputAll f
val () = report ("TextIO.StreamIO.inputAll ", [r1, r2, r3])
