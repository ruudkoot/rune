fun same [] [] = true | same (x :: _) (y :: _) = x = y | same _ _ = false
val _ = same [fn x => x] [fn x => x]
