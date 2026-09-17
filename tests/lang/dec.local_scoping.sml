local
  val secret = 41
  fun helper x = x + secret
in
  val answer = helper 1
  fun twiceHelper x = helper (helper x)
end
val () = print (Int.toString answer ^ " " ^ Int.toString (twiceHelper 0) ^ "\n")
