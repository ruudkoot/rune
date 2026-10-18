(* two names that look alike (UTS #39): scope, and scope in Cyrillic *)
val scope = 1
val ѕсоре = 2
val () = print (Int.toString (scope + ѕсоре) ^ "\n")
