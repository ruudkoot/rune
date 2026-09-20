(* Word: a xorshift generator kept to 30 bits (so that every word size gives
   the same numbers) and bit counting. *)
val mask : word = 0wx3FFFFFFF
fun next (x : word) =
  let val x = Word.andb (Word.xorb (x, Word.<< (x, 0w13)), mask)
      val x = Word.xorb (x, Word.>> (x, 0w17))
  in Word.andb (Word.xorb (x, Word.<< (x, 0w5)), mask) end
fun bits (0w0 : word, n) = n
  | bits (w, n) = bits (Word.>> (w, 0w1), n + Word.toInt (Word.andb (w, 0w1)))
fun loop (0, x, acc) = (x, acc)
  | loop (k, x, acc) = loop (k - 1, next x, acc + bits (x, 0))
val (x, ones) = loop (3000, 0wx2545F491, 0)
val () = print (Word.toString x ^ " " ^ Int.toString ones ^ "\n")
