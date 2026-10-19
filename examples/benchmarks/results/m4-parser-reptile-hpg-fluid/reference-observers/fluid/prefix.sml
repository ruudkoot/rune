functor BenchFluidFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure A=BenchFluidSparseFn(D)
 structure F=A.F
 structure C=BenchIdaFiniteFn(BenchNeed)
 structure R=BenchLinearFloat
 type realv=real D.t
 type triple=realv*realv*realv
 type factors=triple*triple
 type elementFactor=realv*factors
 fun force x=D.force x
 fun cell x=D.delay(fn()=>x)
 fun number x=D.delay(fn()=>R.round x)
 fun add a b=D.delay(fn()=>R.round(force a+force b))
 fun sub a b=D.delay(fn()=>R.round(force a-force b))
 fun mul a b=D.delay(fn()=>R.round(force a*force b))
 fun divide a b=D.delay(fn()=>R.round(force a/force b))
 fun negative a=D.delay(fn()=>R.round(~(force a)))
 fun absolute a=D.delay(fn()=>Real.abs(force a))
 fun sqrt a=D.delay(fn()=>R.round(Math.sqrt(force a)))
 fun eq a b=Real.==(force a,force b)
 fun lt(a:realv)b=force a<force b
 fun le(a:realv)b=force a<=force b
 val zero=number 0.0 val one=number 1.0
 val small=number 1.0e~40 val large=number 1.0e20
 fun mult a b=D.delay(fn()=>if Real.==(force b,0.0)then 0.0 else R.round(force a*force b))
 fun map f values=A.map f values
 fun zipWith f xs ys=map(fn pair=>let val(x,y)=force pair in f x y end)(A.zip xs ys)
 fun concat values=A.flatMap force values
 fun sum values=A.foldLeft add zero values
 fun length values=case force values of F.Nil=>0|F.Cons(_,rest)=>1+length rest
 fun listEq eq xs ys=case(force xs,force ys)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xt),F.Cons(y,yt))=>eq x y andalso listEq eq xt yt|_=>false
 fun intEq a b=force a=force b
 fun pair a b=cell(a,b)
 fun head values=A.head values
 fun tail values=A.tail values
 fun null values=A.null values
 fun range lo hi=A.range lo hi
 fun empty()=F.empty()
 fun singleton value=A.singleton value
 fun triple x y z=(x,y,z)
 fun pairFields p=force p
 fun listInnerProd xs ys=sum(zipWith mul xs ys)
 fun listMatchProd xs ys=sum(zipWith mult xs ys)
 fun addMat a b=A.listArray(A.bounds a)(zipWith add(A.elements a)(A.elements b))
 fun addU(a,b)(c,d)=(addMat a c,addMat b d)
 fun getValues array indices=map(fn i=>A.lookup array(force i))indices
 fun getAssemblyTable total elements nodes steer=
   let val nodeRange=range 1 nodes
       val contributions=A.flatMap(fn e=>
         zipWith(fn i=>fn localIndex=>pair(force i)(cell(singleton(pair(force e)(force localIndex)))))
           (force(A.lookup steer(force e)))nodeRange)(range 1 elements)
       fun appendValues xs ys=D.delay(fn()=>F.append(force xs)(force ys))
       fun equalValues a b=listEq(fn p=>fn q=>force p=force q)(force a)(force b)
   in A.accumArray equalValues appendValues(cell(F.empty()))(1,total)contributions end
 fun elementFactors elements coordinates pressureSteer=
   let
     fun contribution indices=
       case F.toList(force indices)of[n1,n2,n3]=>
         singleton(D.delay(fn()=>
           let val(x1,y1)=force(A.lookup coordinates n1)
               val(x2,y2)=force(A.lookup coordinates n2)
               val(x3,y3)=force(A.lookup coordinates n3)
               val det=sub(mul(sub x2 x1)(sub y3 y1))(mul(sub x1 x3)(sub y1 y2))
               val area=divide(absolute det)(number 2.0)
           in(area,((divide(sub y2 y3)det,divide(sub y3 y1)det,divide(sub y1 y2)det),
                 (divide(sub x3 x2)det,divide(sub x1 x3)det,divide(sub x2 x1)det)))end))
        |_=>F.empty()
   in A.listArray(1,elements)(A.flatMap contribution(A.elements pressureSteer))end
 fun tolerance values differences jacobi=D.delay(fn()=>
   let val absValues=map absolute values
       fun maximum xs=case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>
         A.foldLeft(fn a=>fn b=>D.delay(fn()=>if force a>force b then force a else force b))x rest
       val absMax=maximum absValues
       fun squares xs=sum(map(fn x=>mul x x)xs)
       val squareSum=squares values
       val diffSum=squares(map absolute differences)
   in if lt absMax small orelse lt squareSum small then
       raise Fail(if jacobi then"Jacobi iteration: solution too small!"else"main iteration: solution too small!")
     else force(sqrt(if jacobi orelse le one absMax then divide diffSum squareSum else diffSum))end)
