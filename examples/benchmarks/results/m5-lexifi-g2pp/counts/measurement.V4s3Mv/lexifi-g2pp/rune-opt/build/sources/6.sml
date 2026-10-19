(* LexiFi SAS, copyright 2000-2013. GPL version 3 or later.
 * Direct SML97 translation of the pinned differential-evolution optimizer. *)
structure BenchG2Optimization=
struct
 type termination={maxit:int,maxf:int,target:real}
 datatype status=MaxIterations|MaxEvaluations|TargetReached
 type result={x0:real array,f:real,evaluations:int,status:status}
 exception Infeasible
 fun loop first last f=if first>last then()else(f first;loop(first+1)last f)
 fun copy source=Array.tabulate(Array.length source,fn i=>Array.sub(source,i))
 fun blit source dest=loop 0(Array.length source-1)(fn i=>Array.update(dest,i,Array.sub(source,i)))
 fun parameters n={np=Int.min(10*n,40),cr=0.9}
 fun optimize{np,cr} objective lower upper callback({maxit,maxf,target}:termination)=
   let val n=Array.length lower
       val rng=BenchG2Random.create()
       val calls=ref 0
       fun f x=let val answer=objective x handle Infeasible=>Real.posInf
                   val _=calls:= !calls+1
               in answer end
       val fx=Array.array(np,0.0)
       val best=ref Real.posInf
       val mutations=Array.tabulate(np,fn _=>Array.array(n,0.0))
       val bestIndex=ref 0
       val population=Array.tabulate(np,fn i=>
         let val point=Array.tabulate(n,fn j=>
               let val lo=Array.sub(lower,j)val width=Array.sub(upper,j)-lo
               in lo+width*BenchG2Random.real rng 1.0 end)
             val value=f point
             val _=Array.update(fx,i,value)
             val _=if value< !best then(bestIndex:=i;best:=value;callback(!calls)value)else()
         in point end)
       val x0=copy(Array.sub(population,!bestIndex))
       fun mutation weight i point dest=
         let val drawn=ref[i]val range=ref(np-1)
             fun randomPoint()=
               let val result=ref 0
                   fun adjust value []=(result:=value;[value])
                     |adjust value(all as first::rest)=
                        if first<=value then first::adjust(value+1)rest
                        else(result:=value;value::all)
                   val _=drawn:=adjust(BenchG2Random.integer rng(!range))(!drawn)
                   val _=range:= !range-1
               in Array.sub(population,!result)end
             val first=if BenchG2Random.real rng 1.0<=0.5
                       then Array.sub(population,!bestIndex)else randomPoint()
             val second=randomPoint()
             val third=randomPoint()
             val chosen=BenchG2Random.integer rng n
         in loop 0(n-1)(fn j=>
           let val candidate=Array.sub(first,j)+weight*(Array.sub(second,j)-Array.sub(third,j))
               val value=if(j=chosen orelse BenchG2Random.real rng 1.0<=cr)
                 andalso Array.sub(lower,j)<=candidate andalso candidate<=Array.sub(upper,j)
                 then candidate else Array.sub(point,j)
           in Array.update(dest,j,value)end)end
       fun recombine()=loop 0(np-1)(fn i=>
         let val point=Array.sub(mutations,i)val value=f point
         in if value<Array.sub(fx,i)then
             (Array.update(fx,i,value);blit point(Array.sub(population,i));
              if value< !best then
                (bestIndex:=i;best:=value;callback(!calls)value;blit point x0)else())
            else()end)
       fun result status:result={x0=x0,f= !best,evaluations= !calls,status=status}
       fun iterate remaining=
         let val weight=0.5+BenchG2Random.real rng 0.5
             val _=loop 0(np-1)(fn i=>mutation weight i(Array.sub(population,i))(Array.sub(mutations,i)))
             val _=recombine()
         in if !best<=target then result TargetReached
            else if maxf< !calls then result MaxEvaluations
            else if remaining=0 then result MaxIterations
            else iterate(remaining-1)end
   in iterate maxit end
 type range={lower:real,upper:real,initial:real}
 datatype variable=Fixed of real|Optimize of range
 fun leastSquares absolute feedback maxGlobal parametersOfVector pricer variables quotes=
   let val _=case feedback of NONE=>()|SOME f=>f"Calibrating"
       val(_,indices,subset,initial,lo,hi)=
         Array.foldl(fn(variable,(i,indices,subset,initial,lo,hi))=>
           case variable of Fixed _=>(i+1,indices,true,initial,lo,hi)
            |Optimize{initial=value,lower,upper}=>(i+1,i::indices,subset,value::initial,lower::lo,upper::hi))
           (0,[],false,[],[],[])variables
       val indices=Vector.fromList(rev indices)
       val lower=Array.fromList(rev lo)val upper=Array.fromList(rev hi)
       val parametersOfActive=
         if not subset then parametersOfVector
         else let val all=Array.tabulate(Array.length variables,fn i=>case Array.sub(variables,i)of
                     Fixed value=>value|Optimize _=>Real.posInf-Real.posInf)
              in fn values=>(loop 0(Array.length values-1)(fn i=>Array.update(all,Vector.sub(indices,i),Array.sub(values,i)));parametersOfVector all)end
       val m=Array.length quotes
       val prices=Array.array(m,0.0)
       fun norm acc price quote=
         let val difference=if absolute then price-quote else(price-quote)/quote
         in acc+difference*difference end
       val quoteIndices=Vector.tabulate(m,fn i=>i)
       fun distance prices=Vector.foldl(fn(i,acc)=>norm acc(Array.sub(prices,i))(Array.sub(quotes,i)))0.0 quoteIndices
       val divisor=10000.0/Real.fromInt m
       fun rms error=Math.sqrt(error*divisor)
       fun callback evaluations error=case feedback of NONE=>()|SOME f=>
         f(Int.toString evaluations^" "^Real.toString(rms error))
       val point=if maxGlobal>0 then
           let fun f point=(pricer(parametersOfActive point)prices;distance prices)
               val result=optimize(parameters(Array.length lower))f lower upper callback
                 {maxit=valOf Int.maxInt,maxf=maxGlobal,target=0.0}
           in #x0 result end
         else Array.fromList(rev initial)
       val params=parametersOfActive point
       val _=pricer params prices
   in {parameters=params,rms=rms(distance prices),quoted=quotes,calibrated=prices}end
end
