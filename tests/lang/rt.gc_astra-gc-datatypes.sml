datatype t = Text of string | Pair of t * t | Fun of unit -> string
fun loop n = if n = 0 then 42 else
  let val tree = Pair (Text (Int.toString n), Fun (fn () => Int.toString n))
      val text = case tree of Pair (Text a,Fun f) => a ^ f () | _ => "bad"
  in if text = "bad" then 0 else loop (n-1) end
val _ = print (Int.toString (loop 10000) ^ "\n")
