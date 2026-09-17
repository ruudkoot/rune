fun make offset =
  let fun go [] acc = offset + acc | go (x :: xs) acc = go xs (acc + x)
      val select = fn true => go | false => (fn _ => fn n => n)
  in select true end
val f = make 2
val partial = f [10,20]
val _ = print (Int.toString (partial 10) ^ "\n")
val _ = print (Int.toString ((make 0) [] 42) ^ "\n")
