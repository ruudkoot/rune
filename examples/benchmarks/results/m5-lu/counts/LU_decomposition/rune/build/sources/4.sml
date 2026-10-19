structure Benchmark =
struct
 structure K=BenchSandmarkLU
 val name="LU_decomposition"
 fun close observed expected=BenchInput.closeReal(observed,expected,1.0E~9,1.0E~10)
 fun run [size,path]=
   let val n=BenchInput.between(1,1200)(BenchInput.integer size)
       val state=BenchOCamlRandom.default()
       val original=K.create n(fn _=>fn _=>BenchOCamlRandom.real state 100.0+1.0)
       val lu=K.lup n original
       val(lower,upper)=K.split n lu
       val input=TextIO.openIn path
       fun check i = case TextIO.inputLine input of
           NONE=>if i=n*n then Int.toString n^":checked"else raise Fail "LU fixture too short"
         | SOME line=>
             let val expected=case Real.fromString line of SOME value=>value | NONE=>raise Fail "invalid LU fixture"
             in if i>=n*n then raise Fail "LU fixture too long"else
             let val row=i div n
                 val col=i mod n
                 val wantL=if row>col then expected else if row=col then 1.0 else 0.0
                 val wantU=if row<=col then expected else 0.0
             in if close(Array.sub(lu,i))expected andalso close(Array.sub(lower,i))wantL
                   andalso close(Array.sub(upper,i))wantU then check(i+1)
                else raise Fail("LU factor differs at "^Int.toString i^": got "^Real.toString(Array.sub(lu,i))^", expected "^Real.toString expected)end end
       val result=check 0 handle error=>(TextIO.closeIn input;raise error)
       val _=TextIO.closeIn input
   in result end
   | run _=raise Fail "LU expects matrix-size expected-factors"
end
