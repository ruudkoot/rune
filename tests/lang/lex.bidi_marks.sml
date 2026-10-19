(* lex.bidi: the marks LRM, RLM and ALM may stand in comments, ‎‏؜,
   and in literals; the nine explicit bidi controls nowhere *)
val s : WideString.string = "a‏b"
val () = print "taken\n"
