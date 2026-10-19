(* ^ takes one type of the class String throughout: a string and a wide
   string do not go together *)
val s : string = "a"
val w : WideString.string = "b"
val x = s ^ w
