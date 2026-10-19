(* UTF-8 in a string constant: U+202E RIGHT-TO-LEFT OVERRIDE (bytes E2 80
   AE) between "a" and "b", then "e" and U+0301 COMBINING ACUTE ACCENT
   (bytes CC 81). Section 2.2 allows neither. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
fun show s =
  print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
val () = show "a‮b"
val () = show "é"
