fun outer true = (fn [] => 1 | [x] => x) | outer false = (fn _ => 99)
val _ = outer true [1,2]
