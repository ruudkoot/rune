val (id,constant) = (fn x => x, fn x => fn _ => x)
val _ = if id true then print (Int.toString (id 42) ^ "\n") else ()
val _ = print (constant "ok\n" false)
val _ = print (Int.toString (constant 7 ()) ^ "\n")
