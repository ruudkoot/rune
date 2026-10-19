(* A raw TAB in a character constant, four columns before a multiple of 8:
   MLKit reads four spaces. *)
val tab = #"	"
val () = print (Int.toString (ord tab) ^ "\n")
