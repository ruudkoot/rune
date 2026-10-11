fun f x =
  let val y = x + 1
      val z = y * 2
  in z + y
  end
val r = f 20
val () = print ("r = " ^ Int.toString r ^ "\n")
fun h n = if n = 0 then raise Fail "zero" else h (n - 1)
val s = (h 2 : int) handle Fail m => size m
val () = print ("done " ^ Int.toString s ^ "\n")
