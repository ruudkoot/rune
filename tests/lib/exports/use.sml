structure V = Make (struct val delta = 1 end)
val x : exposed = 1 + 2
val _ = print (Int.toString (Api.value + V.value + x) ^ "\n")
