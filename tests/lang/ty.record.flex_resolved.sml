val v = let val g = fn {x, y, ...} => x + y : int in g {x = 1, y = 2, z = "z"} end
val () = print (Int.toString v ^ "\n")
val w = let fun sel {a, ...} = a in sel {a = "a", b = 1} end
val () = print (w ^ "\n")
(* two selectors of one record, merged, which the next declaration determines *)
fun usage r = #wall r + #user r
val u = usage {wall = 1, user = 2, system = 3}
val () = print (Int.toString u ^ "\n")
