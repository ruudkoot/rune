fun expectPositive (name, source, expected) =
  if RuneLexer.lex source = expected then ()
  else raise Fail ("positive lexer fixture failed: " ^ name)

val _ = expectPositive ("integer", "42",
                        [RuneLexer.TInt 42, RuneLexer.TEOF])
val _ = expectPositive ("keywords", "let val x = true in x end",
                        [RuneLexer.TLet, RuneLexer.TVal, RuneLexer.TIdent "x",
                         RuneLexer.TEq, RuneLexer.TTrue, RuneLexer.TIn,
                         RuneLexer.TIdent "x", RuneLexer.TEnd, RuneLexer.TEOF])
val _ = expectPositive ("operators", "1<>2<=3>=4",
                        [RuneLexer.TInt 1, RuneLexer.TNe, RuneLexer.TInt 2,
                         RuneLexer.TLe, RuneLexer.TInt 3, RuneLexer.TGe,
                         RuneLexer.TInt 4, RuneLexer.TEOF])
val _ = print "positive lexer fixture passed\n"
