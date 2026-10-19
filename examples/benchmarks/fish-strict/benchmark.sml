structure Benchmark =
struct
 structure K=BenchFishFn(BenchStrict)
 val name="fish-strict"
 fun run [count]=
   let val n=BenchInput.between(0,1500)(BenchInput.integer count)
       fun loop i total=if i>n then Int.toString n^":"^Int.toString total else
         let val offset=Int.min(0,i)
             val size=K.length(K.fmt(K.pseudolimit(K.vector(0,0))(K.vector(640+offset,0))(K.vector(0,640+offset))))
         in if size=169363 then loop(i+1)(total+size)else raise Fail "fish formatted length differs"end
   in loop 1 0 end
   | run _=raise Fail "fish expects repetitions"
end
