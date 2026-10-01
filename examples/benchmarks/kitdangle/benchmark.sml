structure Benchmark =
struct
  val name="kitdangle"
  exception Hd
  fun hd(x::_)=x | hd[]=raise Hd
  fun mklist 0=[] | mklist n=n::mklist(n-1)
  fun cycle(payload,p as(m,f))=if m=0 then p else cycle(payload,(m-1,
    let val x=[(m,mklist payload)] in fn()=> #1(hd x)+f() end))
  fun run [depth,payload] =
    let val n=BenchInput.between(1,2000)(BenchInput.integer depth)
        val length=BenchInput.between(1,2000)(BenchInput.integer payload)
        fun one()=let val(remaining,f)=cycle(length,(n,fn()=>0))
                  in if remaining=0 then f() else raise Fail "closure construction" end
    in IntInf.toString(BenchInput.repeat 1 one) end
  | run _=raise Fail "kitdangle expects closure-depth retained-list-length"
end
