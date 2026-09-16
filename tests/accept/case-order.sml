datatype t = A of int * bool | B
val answer = case (print "s"; A (1,true)) of
   A (0,_) => (print "bad"; 0)
 | A (_,false) => (print "bad"; 0)
 | A (1,true) => (print "a"; 42)
 | _ => (print "bad"; 0)
val _ = print (Int.toString answer ^ "\n")
val _ = print (case "a\000b" of "a\000b" => "nul\n" | _ => "bad\n")
val _ = print (case ~1 of 0 => "bad" | ~1 => "negative\n" | _ => "bad")
