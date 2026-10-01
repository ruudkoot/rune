fun outer x = let val id = fn y => y
                in (id x, id true) end
val (n,b) = outer 42
val (s,c) = outer "ok\n"
val _ = if b andalso c then print (Int.toString n ^ "\n" ^ s) else ()
