fun loop n = if n = 0 then 42 else
  let val text = Int.toString n
      val xs = [text, text ^ "!"]
      val fs = [fn () => xs]
      val ys = case fs of f :: _ => f () | [] => []
      val ok = case (xs,ys) of ([a,b],[c,d]) => a=c andalso b=d | _ => false
  in if ok then loop (n-1) else 0 end
val _ = print (Int.toString (loop 10000) ^ "\n")
