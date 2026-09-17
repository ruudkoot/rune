fun sign n = if n < 0 then "neg" else if n = 0 then "zero" else "pos"
val () = print (sign ~1 ^ sign 0 ^ sign 1 ^ "\n")
val () = print (if true then "t" else "f") 
val () = print (if false then "t" else if false then "f" else "g")
val () = print "\n"
