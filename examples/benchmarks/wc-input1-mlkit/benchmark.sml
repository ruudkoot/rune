structure Benchmark=struct val name="wc-input1-mlkit"
fun read()=let val ins=TextIO.openIn "input.txt"
fun loop n=case TextIO.input1 ins of NONE=>n |SOME c=>loop(if c = #"\n" then n+1 else n)
val n=loop 0 val _=TextIO.closeIn ins in n end
fun run [bytes,reps]=let val n=BenchInput.between(1,1000000)(BenchInput.integer bytes) val r=BenchInput.between(1,1000)(BenchInput.integer reps)
val out=TextIO.openOut "input.txt" val _=TextIO.output(out,String.implode(List.tabulate(n,fn i=>if i mod 10=0 then #"\n" else #"a"))) val _=TextIO.closeOut out
fun one()=let val result=read() in if result=(n+9)div 10 then result else raise Fail "newline count"end
val result=BenchInput.repeat r one val _=OS.FileSys.remove "input.txt"
in IntInf.toString result end |run _=raise Fail "wc expects bytes repetitions"end
