(* a file's end ends a top-level declaration, so a flexible record of the file
   before this one (tests/flexrec/usage.sml, in the .cargs) is not determined
   here: whole as in units, and an internal error in neither *)
fun run () = {wall = Time.zeroTime, user = Time.zeroTime, system = Time.zeroTime}
val (w, c) = C.usage (run ())
val () = print (Time.toString c ^ "\n")
