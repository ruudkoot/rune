structure Benchmark =
struct
 structure K=BenchCalendarFn(BenchStrict)
 val name="calendar-strict"
 fun run [year,count]=
   let val base=BenchInput.between(0,1000000)(BenchInput.integer year)
       val n=BenchInput.between(0,50000)(BenchInput.integer count)
       fun loop i total=if i>n then Int.toString n^":"^Int.toString total else
         let val result=K.size(base+i)
         in if result=2888 then loop(i+1)(total+result)else raise Fail "calendar length differs"end
   in loop 1 0 end
   | run _=raise Fail "calendar expects base-year repetitions"
end
