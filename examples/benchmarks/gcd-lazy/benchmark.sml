structure Benchmark =
struct
  val name="gcd-lazy"
  fun extended x y=
    let fun loop((a,b,c),(u,v,w))=if w=0 then(c,BenchLazy.force a,BenchLazy.force b)else
          let val(q,r)=IntInf.quotRem(c,w)
              val left=BenchLazy.delay(fn()=>IntInf.-(BenchLazy.force a,IntInf.*(q,BenchLazy.force u)))
              val right=BenchLazy.delay(fn()=>IntInf.-(BenchLazy.force b,IntInf.*(q,BenchLazy.force v)))
          in loop((u,v,w),(left,right,r))end
    in if x=0 then(y,0,1)else loop((BenchLazy.delay(fn()=>1),BenchLazy.delay(fn()=>0),x),
      (BenchLazy.delay(fn()=>0),BenchLazy.delay(fn()=>1),y))end
  fun calculate d=
    let val ns=BenchStream.fromList(List.tabulate(d+1,fn i=>IntInf.fromInt(5000+i)))
        val ms=BenchStream.fromList(List.tabulate(d+1,fn i=>IntInf.fromInt(10000+i)))
        val pairs=BenchStream.concatMap(fn x=>BenchStream.map(fn y=>(x,y))ms)ns
        val triples=BenchStream.map(fn(x,y)=>(x,y,extended x y))pairs
        val values=BenchStream.map BenchExtendedGCD.consume triples
        val first=BenchStream.head values
    in BenchStream.foldl(fn(x,a)=>if a<x then x else a)first(BenchStream.tail values)end
  fun run args=BenchExtendedGCD.run calculate args
end
