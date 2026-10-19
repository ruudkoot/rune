structure Benchmark =
struct
  val name="bernouilli-strict"
  fun bernoulli n = if n=0 then (1,1) else if n=1 then (~1,2) else if n mod 2=1 then (0,1)
    else let
      val naturals=List.tabulate(n-1,fn i=>IntInf.fromInt(i+2))
      fun zip f ([],_) = [] | zip f (_,[])=[] | zip f(x::xs,y::ys)=f(x,y)::zip f(xs,ys)
      fun power(1,row)=row|power(k,row)=power(k-1,zip IntInf.* (naturals,row))
      val row=power(n,naturals)
      fun negate(_,[])=[]|negate(positive,x::xs)=(if positive then x else IntInf.~ x)::negate(not positive,xs)
      val powers=negate(true,row)
      fun step line=zip IntInf.+ (line@[0],0::line)
      fun loop(k,combs,acc)=if k>n then acc else
        let val terms=zip IntInf.* (powers,List.tl(List.tl combs))
            val total=List.foldl(fn(x,a)=>IntInf.+(a,x))(0:IntInf.int)terms
            val term=BenchRational.ratio(IntInf.-(total,IntInf.fromInt k),IntInf.fromInt(k+1))
        in loop(k+1,step combs,BenchRational.add(acc,term))end
      in loop(2,[1,2,1],(~1,2))end
  fun run args = BenchBernoulliCheck.run bernoulli args
end
