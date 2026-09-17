val r = {b = 2, a = 1, c = "three"}
val {a, b, c} = r
val () = print (Int.toString a ^ Int.toString b ^ c ^ "\n")
val r2 = {c = "x", a = 9, b = 8}
val () = print (Bool.toString (r = r2) ^ Bool.toString (r = {a = 1, b = 2, c = "three"}) ^ "\n")
val nested = {inner = {x = 1}, list = [{y = 2}]}
val () = print (Int.toString (#x (#inner nested) + #y (hd (#list nested))) ^ "\n")
val {1 = one, 2 = two} = (10, 20)
val () = print (Int.toString (one + two) ^ "\n")
