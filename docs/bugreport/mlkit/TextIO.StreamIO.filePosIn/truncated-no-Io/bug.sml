(* filePosIn of an input stream that getReader has truncated *)
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
fun describe f =
  (Position.toString (f ()) ^ ", no exception")
  handle IO.Io {function, name, cause} =>
           "Io {function = \"" ^ function ^ "\", name = \"" ^ name ^ "\", cause = " ^ exnName cause ^ "}"
       | e => exnName e

val () = write ("a.txt", "abc")
val f = TextIO.getInstream (TextIO.openIn "a.txt")
val () = print ("filePosIn before getReader: " ^ describe (fn () => TextIO.StreamIO.filePosIn f) ^ "\n")
val _ = TextIO.StreamIO.getReader f
val () = print ("filePosIn after getReader:  " ^ describe (fn () => TextIO.StreamIO.filePosIn f) ^ "\n")

val g = TextIO.getInstream (TextIO.openIn "a.txt")
val () = TextIO.StreamIO.closeIn g
val () = print ("filePosIn after closeIn:    " ^ describe (fn () => TextIO.StreamIO.filePosIn g) ^ "\n")
