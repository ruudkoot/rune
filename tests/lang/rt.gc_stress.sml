(* allocate far more than the heap and keep a live structure across collections *)
fun mk n = List.tabulate (n, fn i => (i, Int.toString i, [i, i]))
fun churn 0 acc = acc
  | churn n acc = churn (n - 1) (if n mod 1000 = 0 then mk 100 else (ignore (mk 50); acc))
val live = mk 1000
val junk = churn 20000 []
val () = print (Int.toString (length live) ^ " " ^ Int.toString (length junk) ^ "\n")
val () = print (Int.toString (#1 (List.nth (live, 999))) ^ #2 (List.nth (live, 500)) ^ "\n")
val big : string list ref = ref []
val () = List.app (fn i => big := Int.toString i :: !big) (List.tabulate (50000, fn i => i))
val () = print (Int.toString (length (!big)) ^ hd (!big) ^ "\n")
