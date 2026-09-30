val id = fn x => x
val _ = if id true then print (Int.toString (id 42) ^ "\n") else ()
fun identity x = x
val _ = if identity false then () else print (identity "ok\n")
