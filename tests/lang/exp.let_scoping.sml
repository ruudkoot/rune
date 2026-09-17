val x = 1
val y =
  let
    val x = 10
    val z = x + 1
    fun f a = a + z
  in
    f x
  end
val () = print (Int.toString x ^ " " ^ Int.toString y ^ "\n")
val z = let val a = 1 val b = 2 in a + b; a * b end
val () = print (Int.toString z ^ "\n")
val () = let in print "empty let\n" end
