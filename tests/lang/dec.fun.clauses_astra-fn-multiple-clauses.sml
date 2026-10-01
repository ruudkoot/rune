val describe = fn [] => 0 | [x] => x | x :: y :: _ => x + y
val choose = fn true => (fn x => x) | false => (fn x => x)
val _ = print (Int.toString (describe [] + describe [2] + describe [10,30,99]) ^ "\n")
val _ = print (choose false "yes\n")
val _ = print (Int.toString (choose true 42) ^ "\n")
