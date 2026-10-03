structure Benchmark =
struct
  val name="wheel-sieve1-lazy"
  datatype wheel=Wheel of IntInf.int BenchLazy.delay * IntInf.int BenchStream.stream
  fun nextSize (Wheel(size,ns),p:IntInf.int)=
    let val s=BenchLazy.force size
        val offsets=BenchWheelCheck.range(0,fn()=>IntInf.*(IntInf.-(p,1),s),s)
        val values=BenchStream.concatMap (fn offset=>BenchStream.map(fn n=>IntInf.+(n,offset))ns)offsets
        val filtered=BenchStream.filter(fn n=>IntInf.rem(n,p)>0)values
    in Wheel(BenchLazy.delay(fn()=>IntInf.*(s,p)),filtered)end
  fun wheels ps=BenchStream.fix(fn self=>BenchStream.Cons
    (BenchLazy.delay(fn()=>Wheel(BenchLazy.delay(fn()=>1),BenchStream.singleton(1:IntInf.int))),
      BenchStream.zipWith nextSize self ps))
  fun notDivBy ps qs n =
    let val q=BenchStream.head qs
    in q>n orelse (IntInf.rem(n,BenchStream.head ps)>0 andalso
      notDivBy(BenchStream.tail ps)(BenchStream.tail qs)n)end
  fun sieve ws ps qs guard=BenchLazy.delay(fn()=>
    let val Wheel(size,ns)=BenchStream.head ws
        val s=BenchLazy.force size
        val offsets=BenchStream.cons(BenchLazy.delay(fn()=>s),
          BenchWheelCheck.range(IntInf.*(2,s),fn()=>IntInf.*(IntInf.min(guard,IntInf.-(BenchStream.head ps,1)),s),s))
        val values=BenchStream.concatMap(fn offset=>BenchStream.map(fn n=>IntInf.+(n,offset))ns)offsets
        val first=BenchStream.filter(fn n=>s<=2 orelse notDivBy ps qs n)values
        val rest=BenchLazy.delay(fn()=>BenchLazy.force(sieve(BenchStream.tail ws)(BenchStream.tail ps)(BenchStream.tail qs)guard))
    in BenchLazy.force(BenchStream.append first rest)end)
  fun prime n =
    let val input=IntInf.fromInt n val guard=IntInf.*(input,input)
        val primes=BenchStream.fix(fn self=>BenchLazy.force(sieve(wheels self)self
          (BenchStream.map(fn p=>IntInf.*(p,p))self)guard))
    in BenchStream.nth primes n end
  fun run args=BenchWheelCheck.run prime args
end
