 val exceptionOne:domainInt=cell(MkExInt(int 1,F.empty()))
 val exceptionTwo:domainInt=cell(MkExInt(int 2,F.empty()))
 fun isTwo value=case force value of Two=>true|_=>false
 fun singletonValue values=case force values of F.Cons(x,rest)=>if null rest then SOME x else NONE|F.Nil=>NONE
 fun normalizeSizeDomain domain:domain=D.delay(fn()=>case force domain of Two=>Two
   |Lift1 ds=>(case singletonValue ds of SOME value=>(case force value of Lift1 values=>Lift2(map normalizeSizeDomain values)
       |_=>Lift1(map normalizeSizeDomain ds))|NONE=>Lift1(map normalizeSizeDomain ds))
   |Lift2 ds=>(case singletonValue ds of SOME value=>(case force value of Lift1 values=>
          let val inner=cell(Lift2(map normalizeSizeDomain values))in Lift1(singleton inner)end
         |_=>Lift2(map normalizeSizeDomain ds))|NONE=>Lift2(map normalizeSizeDomain ds))
   |Func(arguments,result)=>
      let fun fallback()=Func(insertionSort compareDomain(map normalizeSizeDomain arguments),normalizeSizeDomain result)
          val two=cell Two
      in case singletonValue arguments of NONE=>fallback()|SOME argument=>
        case(force argument,force result)of
          (Two,Two)=>Lift1(singleton two)
         |(Lift1 ds,Two)=>if isSingletonList ds andalso isTwo(head ds)then Lift2(singleton two)else fallback()
         |(Lift2 ds,Two)=>if isSingletonList ds andalso isTwo(head ds)then
              let val inner=cell(Lift2(singleton two))in Lift1(singleton inner)end else fallback()
         |(Two,Lift1 ds)=>if isSingletonList ds andalso isTwo(head ds)then Func(F.fromList[Two,Two],two)else fallback()
         |(Two,Lift2 ds)=>if isSingletonList ds andalso isTwo(head ds)then
              let val inner=cell(Lift1(singleton two))in Func(singleton inner,inner)end else fallback()
         |_=>fallback()
      end)
 fun latticeCardinality table domain:domainInt=D.delay(fn()=>case force domain of
    Two=>force exceptionTwo
   |Lift1 ds=>force(addException exceptionOne(foldLeft multiplyException exceptionOne(map(latticeCardinality table)ds)))
   |Lift2 ds=>force(addException exceptionTwo(foldLeft multiplyException exceptionOne(map(latticeCardinality table)ds)))
   |Func(arguments,result)=>
      let fun fix x=let val y=normalizeSizeDomain x in if equalDomain x y then x else fix y end
          val normalized=fix(cell(Func(arguments,result)))
          fun lookup rows=case force rows of F.Nil=>MkExInt(int 0,singleton normalized)
            |F.Cons(entry,rest)=>let val(d,n)=force entry
              in if equalDomain d normalized then MkExInt(n,F.empty())else lookup rest end
      in case force normalized of Func _=>lookup table|_=>force(latticeCardinality table normalized)end)
 fun reduceDomain domain=F.defer(fn()=>case force domain of
    Two=>F.empty()
   |Lift1 ds=>let val alternatives=zipExact(fn d=>fn choices=>F.cons(d,choices))ds(map reduceDomain ds)
      in F.append(map(fn reduced=>cell(Lift1 reduced))(tail(cartesianProduct alternatives)))(singleton(cell Two))end
   |Lift2 ds=>let val alternatives=zipExact(fn d=>fn choices=>F.cons(d,choices))ds(map reduceDomain ds)
      in F.append(map(fn reduced=>cell(Lift2 reduced))(tail(cartesianProduct alternatives)))(singleton(cell Two))end
   |Func(arguments,result)=>
      let val argReductions=map reduceDomain arguments
          val resultReduced=reduceDomain result
          val originals=F.cons(result,arguments)
          val reduced=F.cons(resultReduced,argReductions)
          val choices=zipExact(fn d=>fn variants=>F.cons(d,variants))originals reduced
          val variants=tail(cartesianProduct choices)
          val functions=map(fn values=>cell(Func(tail values,head values)))variants
      in F.append functions(singleton(cell Two))end)
