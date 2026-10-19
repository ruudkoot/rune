structure Benchmark =
struct
  val name="pidigits-nofib-lazy"
  type coefficient=IntInf.int BenchLazy.delay
  fun stream(j,n:coefficient,a:coefficient,d:coefficient)=BenchLazy.delay(fn()=>
    let val k=j+1 val factor=IntInf.fromInt k val y=IntInf.fromInt(2*k+1)
        val n'=BenchLazy.delay(fn()=>IntInf.*(BenchLazy.force n,factor))
        val a'=BenchLazy.delay(fn()=>IntInf.*(IntInf.+(BenchLazy.force a,IntInf.*(BenchLazy.force n,2)),y))
        val d'=BenchLazy.delay(fn()=>IntInf.*(BenchLazy.force d,y))
        fun advance()=BenchLazy.force(stream(k,n',a',d'))
        val numerator=BenchLazy.force n' val addition=BenchLazy.force a'
    in if numerator>addition then advance()else
      let val denominator=BenchLazy.force d'
          val(q,r)=BenchNofibPi.candidate(numerator,addition,denominator)
      in if IntInf.+(r,numerator)>=denominator then advance()else
        BenchStream.Cons(BenchLazy.delay(fn()=>Char.chr(Char.ord #"0"+IntInf.toInt q)),
          BenchLazy.delay(fn()=>BenchLazy.force(stream(k,
            BenchLazy.delay(fn()=>IntInf.*(numerator,10)),
            BenchLazy.delay(fn()=>IntInf.*(IntInf.-(addition,IntInf.*(q,denominator)),10)),d'))))end end)
  fun digits n=BenchStream.take n(stream(0,BenchLazy.delay(fn()=>1),BenchLazy.delay(fn()=>0),BenchLazy.delay(fn()=>1)))
  fun run args=BenchNofibPi.run digits args
end
