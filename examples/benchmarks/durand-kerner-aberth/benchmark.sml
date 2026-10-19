structure Benchmark =
struct
  val name="durand-kerner-aberth"
  structure K=BenchDurandKerner
  structure F=BenchDurandKernerFiles
  val inputs=BenchLazy.delay(fn()=>F.coefficients "data/coefficients.txt")
  fun run [percentage,path]=
    let val percent=BenchInput.between(3,100)(BenchInput.integer percentage)
        val data=BenchLazy.force inputs val count=Array.length data*percent div 100
        val selected=Array.tabulate(count,fn i=>Array.sub(data,i))
        val expected=F.reference path
        val _=if #count expected=count-1 then()else raise Fail "root reference profile differs"
        fun loop 0 total=total
          | loop n total=(F.check expected(K.roots selected);loop(n-1)(total+count-1))
        val checked=loop 10 0
    in Int.toString percent^":"^Int.toString checked^":checked"end
    | run _=raise Fail "roots expect percentage and reference"
end
