structure Benchmark =
struct
  val name="wheel-sieve2-lazy"
  datatype wheel=Wheel of IntInf.int BenchLazy.delay * IntInf.int BenchStream.stream * IntInf.int BenchStream.stream
  fun nextSize(Wheel(size,ms,ns),p:IntInf.int,q:IntInf.int)=
    let val s=BenchLazy.force size
        fun turn0(n,rs)=if IntInf.rem(n,p)>0 then BenchStream.cons(BenchLazy.delay(fn()=>n),rs)else rs
        fun turn offset (n,rs)=let val v=IntInf.+(offset,n)
          in if IntInf.rem(v,p)>0 then BenchStream.cons(BenchLazy.delay(fn()=>v),rs)else rs end
        fun roll count offset=BenchLazy.delay(fn()=>if count=0 then BenchStream.Nil else
          BenchLazy.force(BenchStream.foldrStream(turn offset)
            (BenchStream.foldrStream(turn offset)(roll(IntInf.-(count,1))(IntInf.+(offset,s)))ns)ms))
        val generated=BenchStream.foldrStream turn0 (roll(IntInf.-(p,1))s)ns
        val (xs,ns')=BenchStream.span(fn n=>n<=q)generated
        val ms'=BenchStream.foldrStream turn0 xs ms
    in Wheel(BenchLazy.delay(fn()=>IntInf.*(s,p)),ms',ns')end
  fun wheels ps=BenchLazy.delay(fn()=>BenchStream.Cons
    (BenchLazy.delay(fn()=>Wheel(BenchLazy.delay(fn()=>1),BenchStream.singleton(1:IntInf.int),BenchStream.empty())),
      BenchLazy.delay(fn()=>BenchLazy.force(BenchStream.zipWith3 nextSize (wheels ps)ps
        (BenchStream.map(fn p=>IntInf.*(p,p))ps)))))
  fun spiral ws ps qs guard=BenchLazy.delay(fn()=>
    let val Wheel(size,ms,ns)=BenchStream.head ws
        val s=BenchLazy.force size
        val q=BenchLazy.delay(fn()=>IntInf.min(guard,BenchStream.head qs))
        val sp=BenchLazy.delay(fn()=>BenchLazy.force(spiral(BenchStream.tail ws)(BenchStream.tail ps)(BenchStream.tail qs)guard))
        fun turn0(n,rs)=if n<BenchLazy.force q then BenchStream.cons(BenchLazy.delay(fn()=>n),rs)else sp
        fun turn offset (n,rs)=let val v=IntInf.+(offset,n)
          in if v=2 orelse v<BenchLazy.force q then BenchStream.cons(BenchLazy.delay(fn()=>v),rs)
            else BenchStream.dropWhile(fn x=>x<v)sp end
        fun roll offset=BenchLazy.delay(fn()=>BenchLazy.force(BenchStream.foldrStream(turn offset)
          (BenchStream.foldrStream(turn offset)(roll(IntInf.+(offset,s)))ns)ms))
    in BenchLazy.force(BenchStream.foldrStream turn0(roll s)ns)end)
  fun prime n =
    let val input=IntInf.fromInt n val square=IntInf.*(input,input) val guard=IntInf.*(square,square)
        val primes=BenchStream.fix(fn self=>BenchLazy.force(spiral(wheels self)self
          (BenchStream.map(fn p=>IntInf.*(p,p))self)guard))
    in BenchStream.nth primes n end
  fun run args=BenchWheelCheck.run prime args
end
