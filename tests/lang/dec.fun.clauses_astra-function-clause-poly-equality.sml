fun same [] [] = true
  | same (x :: xs) (y :: ys) = x = y andalso same xs ys
  | same _ _ = false
val eq = fn ([],[]) => true | (x :: _, y :: _) => x = y | _ => false
val _ = if same [1,2] [1,2] andalso same ["yes"] ["yes"] andalso
  eq ([true],[true]) andalso eq ([42],[42]) then print "yes\n" else print "bad\n"
