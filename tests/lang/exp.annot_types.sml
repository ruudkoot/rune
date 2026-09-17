val x : int = 5
val f = fn (a : int, b : string) => (Int.toString a ^ b : string)
val g : int -> int = fn x => x * 2
val () = print (f (x, "!") ^ Int.toString (g 3) ^ "\n")
val l = [] : string list
val () = print (Int.toString (length l) ^ "\n")
