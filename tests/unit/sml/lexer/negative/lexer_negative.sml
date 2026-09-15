fun expectNegative (name, source) =
  ((RuneLexer.lex source; raise Fail ("negative lexer fixture accepted: " ^ name))
   handle Fail _ => ()
        | Overflow => ())

val _ = expectNegative ("invalid-character", "@")
val _ = expectNegative ("invalid-number", "12.34")
val _ = expectNegative ("integer-overflow",
                        "999999999999999999999999999999999999999999")
val _ = print "negative lexer fixture passed\n"
