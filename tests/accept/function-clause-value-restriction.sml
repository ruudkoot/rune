val fs = [fn [] => [] | x :: xs => x :: xs]
val _ = case fs of [f] => print (Int.toString (case f [42] of [n] => n | _ => 0) ^ "\n") | _ => ()
val _ = case fs of [f] => (case f ["yes\n"] of [s] => print s | _ => ()) | _ => ()
