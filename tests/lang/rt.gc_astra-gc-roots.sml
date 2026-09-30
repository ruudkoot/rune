fun churn n = if n = 0 then ()
              else let val _ = Int.toString n ^ "!" in churn (n - 1) end
fun makeRecursive text =
  let fun f n = if n = 0 then text else (churn 10; f (n - 1))
  in f end
fun caller n =
  let val text = Int.toString n ^ " kept"
      val nested = ((text, text), (text, text))
      val read = fn () => nested
      val _ = churn 20
  in if read () = nested then text else "lost" end
fun consume (text, ()) = text
fun tailString n = Int.toString n
fun tailToSmall (text, (), ()) = tailString 42
val _ = print (consume (caller 7, churn 20) ^ "\n")
val _ = print ((Int.toString 12 ^ Int.toString 34) ^ "\n")
val _ = print ((makeRecursive (caller 8)) 10 ^ "\n")
val _ = print (tailToSmall (caller 9, (), ()) ^ "\n")
val _ = print ((let val a = caller 10 in (churn 20; a) end) ^ "\n")
