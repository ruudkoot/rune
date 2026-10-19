structure Benchmark =
struct
  val name="bernouilli-lazy"
  val naturals=BenchStream.iterate (fn n=>IntInf.+(n,1)) (BenchLazy.delay(fn()=>2:IntInf.int))
  val powers=BenchStream.fix(fn self=>BenchStream.Cons(BenchLazy.delay(fn()=>naturals),
    BenchStream.map (fn line=>BenchStream.zipWith IntInf.* naturals line) self))
  val signs=BenchStream.iterate not (BenchLazy.delay(fn()=>true))
  val negatives=BenchStream.map (fn line=>BenchStream.zipWith
    (fn (positive,x)=>if positive then x else IntInf.~ x) signs line) powers
  val pascal=BenchStream.iterate
    (fn line=>BenchStream.zipWith IntInf.+ (BenchStream.append line (BenchStream.singleton (0:IntInf.int)))
      (BenchStream.cons(BenchLazy.delay(fn()=>0:IntInf.int),line)))
    (BenchLazy.delay(fn()=>BenchStream.fromList[1,2,1]:IntInf.int BenchStream.stream))
  fun bernoulli n = if n=0 then (1,1) else if n=1 then (~1,2) else if n mod 2=1 then (0,1)
    else let val ns=BenchStream.nth negatives (n-1)
      fun loop(k,rows,acc)=if k>n then acc else
        let val combs=BenchStream.tail(BenchStream.tail(BenchStream.head rows))
            val terms=BenchStream.zipWith IntInf.* ns combs
            val total=BenchStream.foldl (fn(x,a)=>IntInf.+(a,x)) (0:IntInf.int) terms
            val term=BenchRational.ratio(IntInf.-(total,IntInf.fromInt k),IntInf.fromInt(k+1))
        in loop(k+1,BenchStream.tail rows,BenchRational.add(acc,term))end
      in loop(2,pascal,(~1,2))end
  fun run args = BenchBernoulliCheck.run bernoulli args
end
