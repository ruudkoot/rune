(* output1 and output on an output stream that has been closed *)
fun describe f =
  (f (); "no exception")
  handle IO.Io {function, name, cause} =>
           "Io {function = \"" ^ function ^ "\", name = \"" ^ name ^ "\", cause = " ^ exnName cause ^ "}"
       | e => exnName e

val out = TextIO.openOut "a.txt"
val () = TextIO.closeOut out
val () = print ("TextIO.output1: " ^ describe (fn () => TextIO.output1 (out, #"x")) ^ "\n")
val () = print ("TextIO.output:  " ^ describe (fn () => TextIO.output (out, "x")) ^ "\n")

val bout = BinIO.openOut "b.bin"
val () = BinIO.closeOut bout
val () = print ("BinIO.output1:  " ^ describe (fn () => BinIO.output1 (bout, 0w120)) ^ "\n")
