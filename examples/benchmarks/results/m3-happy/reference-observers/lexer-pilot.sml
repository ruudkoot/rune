structure X=BenchHappyLexerFn(BenchNeed)
fun collect chars line=X.lexer(fn token=>fn rest=>fn at=>
  case token of X.EOF=>X.return[]rest at
   |_=>X.fmap(fn tail=>token::tail)collect rest at)chars line
val _=case collect(X.input"%token x { T }\n%%\nr : x { $1 }")1 of
  X.Ok tokens=>print(Int.toString(List.length tokens)^"\n")
 |X.Failed message=>raise Fail(X.string message)
