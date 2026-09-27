exception E
fun f (n : int) : unit = if n = 0 then raise E else List.app f []
val () = f 0 handle E => print "1\n"
