(* A Latin-1 file can write a wide character through an ASCII escape. *)
val character : WideChar.char = #"\u03BB"
val () = print (Int.toString (WideChar.ord character) ^ "\n")
