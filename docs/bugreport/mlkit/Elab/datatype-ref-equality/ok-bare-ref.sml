val r = ref (fn x : int => x)
val () = print (if r = r andalso r <> ref (fn x => x) then "equal when the same\n" else "wrong\n")
