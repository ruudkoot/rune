(* two constants and no operator: their types clash, as an int and a
   string do *)
fun f x = case x of 0 => "a" | n => n
