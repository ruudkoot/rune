datatype chain = End | Link of chain
fun build n rest = if n = 0 then rest else build (n-1) (Link rest)
val retained = build 10000 End
