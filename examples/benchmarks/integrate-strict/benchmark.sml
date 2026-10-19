structure Benchmark =
struct
  val name = "integrate-strict"
  fun run [size,reference] =
    let val n=BenchInput.between (1,5000000) (BenchInput.integer size)
        val _=if List.exists (fn p=>p=reference)
          ["expected/smoke.txt","expected/normal.txt","expected/large.txt"] then () else raise Fail "integration reference path"
        fun ints i=if i>n then [] else Real.fromInt i::ints(i+1)
        val inputs=ints 1
        val zs=List.map (fn u=>BenchIntegrate.zark u (2.0*u)) inputs
        val powers=List.map BenchIntegrate.fourth inputs
        fun running ([]:real list)=[] | running(x::xs)=
          let fun more([],_) = [] | more(y::ys,acc)=let val next=y+acc in next::more(ys,next)end
          in x::more(xs,x)end
        fun errors([],[])=[] | errors(x::xs,y::ys)=let val d=x-y in d*d::errors(xs,ys)end
          | errors _=raise Fail "integration length mismatch"
        val rr=running zs
        val ii=running powers
        val es=errors(rr,ii)
        val result=List.foldl (fn(x,a)=>a+x) 0.0 es
    in BenchIntegrate.checked n (result,List.nth(rr,n-1),List.nth(ii,n-1)) reference end
    | run _ = raise Fail "integrate expects range reference"
end
