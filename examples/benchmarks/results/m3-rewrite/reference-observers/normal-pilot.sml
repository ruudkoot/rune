structure Need=BenchRewriteFn(val eagerChildren=false)
structure Strict=BenchRewriteFn(val eagerChildren=true)
fun run label f = let val start=Time.now() val result=f 250000
 in if result then print(label^" "^Time.toString(Time.-(Time.now(),start))^"\n")else raise Fail "incorrect result"end
val _=run "lazy" Need.test
val _=run "strict" Strict.test
