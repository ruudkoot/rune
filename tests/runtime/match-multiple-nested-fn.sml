val f = fn [] => (fn 0 => 1 | _ => 2) | [x] => (fn n => x + n)
val _ = f (print "first\n"; [1,2]) (print "second\n"; 0)
