(* err.flex_later_file, compiled in units: refused the same *)
fun run () = {wall = Time.zeroTime, user = Time.zeroTime, system = Time.zeroTime}
val (w, c) = C.usage (run ())
val () = print (Time.toString c ^ "\n")
