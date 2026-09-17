val () = print (Bool.toString true ^ Bool.toString false ^ Bool.toString (Bool.not true) ^ "\n")
val () = print (Bool.toString (valOf (Bool.fromString "true")) ^ Bool.toString (valOf (Bool.fromString "false")) ^ Bool.toString (isSome (Bool.fromString "x")) ^ "\n")
