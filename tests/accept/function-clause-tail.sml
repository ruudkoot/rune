fun loop 0 total = total
  | loop n total =
      let val text = Int.toString n ^ "!"
          val next = fn true => loop | false => loop
      in if n = 1 then next true (n - 1) (total + 1)
         else ((); case true of true => next false (n - 1) total | false => total)
      end
val _ = print (Int.toString (loop 100000 0) ^ "\n")
