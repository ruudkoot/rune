(* A raw TAB in a character constant. It stands one column before a
   multiple of 8, so MLKit reads #" ". Expected: a compile-time error. *)
val theTab = #"	"
val () = print (Int.toString (ord theTab) ^ "\n")
