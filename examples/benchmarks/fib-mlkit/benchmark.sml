structure Benchmark=struct val name="fib-mlkit"
fun run [size]=let val n=BenchInput.between(0,30)(BenchInput.integer size)
val _=BenchOutput.reset()
fun print s=BenchOutput.put s fun printNum i=print(Int.toString i)
fun neq(x,y)=if x<y then false else if x>y then false else true
fun fib x=let val _=print "In FIB\n" val _=printNum x
in if neq(x,0)orelse neq(x,1)then 1 else fib(x-2)+fib(x-1)end
val _=print "Before fib\n" val result=fib n val _=printNum result val _=print "After fib\n"
in Int.toString result^" "^BenchOutput.summary()end |run _=raise Fail "fib-mlkit expects recurrence input"end
