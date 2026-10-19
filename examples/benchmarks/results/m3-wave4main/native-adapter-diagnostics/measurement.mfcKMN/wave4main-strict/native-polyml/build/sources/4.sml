functor BenchWaveArrayFn(D:BENCH_SUSPEND)=
struct
 datatype 'a node=Array of{lower:int,upper:int,cells:'a D.t vector}
 type 'a array='a node D.t
 fun defer f=D.delay(fn()=>D.force(f()))
 fun tabulate f(lower,upper)=D.delay(fn()=>
   Array{lower=lower,upper=upper,cells=Vector.tabulate(Int.max(0,upper-lower+1),fn offset=>D.delay(fn()=>f(lower+offset)))})
 fun bounds array=case D.force array of Array{lower,upper,...}=>(lower,upper)
 fun sub array index=case D.force array of Array{lower,upper,cells}=>
   if index<lower orelse index>upper then raise Subscript else D.force(Vector.sub(cells,index-lower))
 fun append array value=defer(fn()=>
   let val(lower,upper)=bounds array
   in tabulate(fn i=>if i>upper then value else sub array i)(lower,upper+1)end)
 fun prepend array value=defer(fn()=>
   let val(lower,upper)=bounds array
   in tabulate(fn i=>if i<lower then value else sub array i)(lower-1,upper)end)
 fun values array=let val(lower,upper)=bounds array
   in List.tabulate(Int.max(0,upper-lower+1),fn i=>sub array(lower+i))end
end
