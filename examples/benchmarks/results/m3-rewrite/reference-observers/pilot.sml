structure B=BenchRewriteFn(val eagerChildren=false)
val _=print(Bool.toString(B.test 1)^"\n")
val _=BenchStream.foldl(fn(e,())=>print(Int.toString(B.number e)^" "^B.render(B.lhs e)^"="^B.render(B.rhs e)^"\n"))()(B.rules B.completion)
