(* the lines of bug.sml at Int32.int and Word32.word, which MLKit accepts *)
val a : Int32.int = 63
val b = fn (x : Int32.int, y) => x + y
val c : Word32.word = 0wxFFFF
val () = print (Int32.toString (b (a, 1)) ^ " " ^ Word32.toString c ^ "\n")
