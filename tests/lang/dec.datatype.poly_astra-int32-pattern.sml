val a = case ~2147483648 of ~2147483648 => true | _ => false
val b = case 2147483647 of 2147483647 => true | _ => false
val _ = print (if a andalso b then "yes\n" else "no\n")
