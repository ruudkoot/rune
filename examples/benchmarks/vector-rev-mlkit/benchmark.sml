structure Benchmark=struct val name="vector-rev-mlkit"
fun reverse v=let val len=Vector.length v in Vector.tabulate(len,fn i=>Vector.sub(v,len-1-i))end
fun run [size,trials]=let val n=BenchInput.between(1,10000)(BenchInput.integer size) val r=BenchInput.between(0,1000000)(BenchInput.integer trials)

fun one()=let val input=Vector.tabulate(n,fn i=>(i,i)) val result=reverse(reverse input)
fun scan(k,sum)=if k=n then sum else let val i=k val (x,y)=Vector.sub(result,k)
in if x=i andalso y=i then scan(k+1,IntInf.+(sum,IntInf.fromInt(2*i)))else raise Fail "vector contents"end
in scan(0,0)end
fun loop(k,sum)=if k<0 then sum else loop(k-1,IntInf.+(sum,one()))
in IntInf.toString(loop(r,0))end |run _=raise Fail "vector expects length initial trial counter" end
