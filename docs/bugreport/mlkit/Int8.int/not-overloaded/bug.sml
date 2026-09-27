(* The specification puts Int<N>.int in the overloading class int and
   Word<N>.word in word (the top-level environment chapter), so integer and
   word constants and the overloaded operators (+, <, ...) are available at
   Int8.int, Int16.int and Word16.word.  MLKit rejects each of the lines below;
   the same lines at Int32.int and Word32.word compile. *)
val a : Int8.int = 63
val b = fn (x : Int16.int, y) => x + y
val c : Word16.word = 0wxFFFF
val () = print (Int8.toString a ^ "\n")
