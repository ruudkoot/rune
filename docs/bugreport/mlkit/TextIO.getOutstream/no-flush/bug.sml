(* getOutstream and setOutstream on an output stream with buffered output *)
fun slurp name = let val ins = TextIO.openIn name in TextIO.inputAll ins before TextIO.closeIn ins end
fun report (what, name) = print (what ^ ": the file holds \"" ^ slurp name ^ "\"\n")

(* a file that is not a terminal: TextIO.openOut makes it block buffered *)
val out = TextIO.openOut "a.txt"
val () = TextIO.output (out, "ab")
val _ = TextIO.getOutstream out
val () = report ("after getOutstream", "a.txt")

val out = TextIO.openOut "b.txt"
val () = TextIO.output (out, "ab")
val other = TextIO.openOut "c.txt"
val () = TextIO.setOutstream (out, TextIO.getOutstream other)
val () = report ("after setOutstream", "b.txt")
