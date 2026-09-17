val inc = fn x => x + 1
val sel = fn (a, _) => a
val classify = fn 0 => "zero" | 1 => "one" | _ => "many"
val () = print (Int.toString (inc 1) ^ Int.toString (sel (7, 8)) ^ classify 0 ^ classify 1 ^ classify 9 ^ "\n")
val () = print (Int.toString ((fn x => fn y => x * y) 6 7) ^ "\n")
