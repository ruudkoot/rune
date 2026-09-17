val rec fact = fn 0 => 1 | n => n * fact (n - 1)
val rec even = fn 0 => true | n => odd (n - 1)
and odd = fn 0 => false | n => even (n - 1)
val () = print (Int.toString (fact 10) ^ " " ^ Bool.toString (even 10) ^ " " ^ Bool.toString (odd 10) ^ "\n")
