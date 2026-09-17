fun choose true = (fn [] => [] | x :: xs => x :: xs) | choose false = (fn x => x)
val f = choose true
val _ = f [1]
val _ = f [true]
