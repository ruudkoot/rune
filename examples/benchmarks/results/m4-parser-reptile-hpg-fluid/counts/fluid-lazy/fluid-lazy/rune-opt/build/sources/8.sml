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
 val massRowSums=A.defListArray eq(1,6)(divide(number 12.0)(number 180.0))
   (F.fromList[force(divide(number 12.0)(number 180.0)),force(divide(number 12.0)(number 180.0)),
     force(divide(number 12.0)(number 180.0)),force(divide(number 68.0)(number 180.0)),
     force(divide(number 68.0)(number 180.0)),force(divide(number 68.0)(number 180.0))])
 val massMatrix=let val inverse=divide one(number 180.0)
     val rows=[[6,~1,~1,~4,0,0],[~1,6,~1,0,~4,0],[~1,~1,6,0,0,~4],
       [~4,0,0,32,16,16],[0,~4,0,16,32,16],[0,0,~4,16,16,32]]
   in A.listArray(1,6)(F.fromList(List.map(fn row=>
     map(mult inverse)(F.fromList(List.map Real.fromInt row)))rows))end
 fun components((a,b,c),(x,y,z))=(a,b,c,x,y,z)
 fun ff1 x y u v=add(mul x y)(mul u v)
 fun ff2 x y u v=let fun part x y=add(mul x(add x y))(mul y y)
   in add(part x y)(part u v)end
 fun ff3 x y z u v w=let fun part x y z=add(mul x y)(mul(add x z)(add y z))
   in add(part x y z)(part u v w)end
 fun f0 _=zero
 fun f11((x,_,_),(y,_,_))=mul(number 3.0)(ff1 x x y y)
 fun f12((x,y,_),(u,v,_))=negative(ff1 x y u v)
 fun f13((x,_,z),(u,_,w))=negative(ff1 x z u w)
 fun f15 value=mul(number(~4.0))(f13 value)
 fun f16 value=mul(number(~4.0))(f12 value)
 fun f22((_,x,_),(_,y,_))=mul(number 3.0)(ff1 x x y y)
 fun f23((_,y,z),(_,v,w))=negative(ff1 y z v w)
 fun f24 value=mul(number(~4.0))(f23 value)
 fun f33((_,_,x),(_,_,y))=mul(number 3.0)(ff1 x x y y)
 fun f44((_,y,z),(_,v,w))=mul(number 8.0)(ff2 y z v w)
 fun f45((x,y,z),(u,v,w))=mul(number 4.0)(ff3 x y z u v w)
 fun f46((x,y,z),(u,v,w))=mul(number 4.0)(ff3 x z y u w v)
 fun f55((x,_,z),(u,_,w))=mul(number 8.0)(ff2 x z u w)
 fun f56((x,y,z),(u,v,w))=mul(number 4.0)(ff3 y z x v w u)
 fun f66((x,y,_),(u,v,_))=mul(number 8.0)(ff2 x y u v)
 val diffusionMatrix=
   let val rows=[[f11,f12,f13,f0,f15,f16],[f12,f22,f23,f24,f0,f16],
      [f13,f23,f33,f24,f15,f0],[f0,f24,f24,f44,f45,f46],
      [f15,f0,f15,f45,f55,f56],[f16,f16,f0,f46,f56,f66]]
   in A.listArray(1,6)(F.fromList(List.map(fn row=>fn factors=>
     map(fn f=>force f factors)(F.fromList row))rows))end
 val gradientMatrix=
   let fun row1(a,b,c)=F.cons(a,F.cons(zero,F.cons(zero,F.empty())))
       fun row2(a,b,c)=F.cons(zero,F.cons(b,F.cons(zero,F.empty())))
       fun row3(a,b,c)=F.cons(zero,F.cons(zero,F.cons(c,F.empty())))
       fun row4(a,b,c)=F.cons(add b c,F.cons(add(add b c)c,F.cons(add(add c b)b,F.empty())))
       fun row5(a,b,c)=F.cons(add(add a c)c,F.cons(add a c,F.cons(add(add c a)a,F.empty())))
       fun row6(a,b,c)=F.cons(add(add a b)b,F.cons(add(add a a)b,F.cons(add a b,F.empty())))
   in A.listArray(1,6)(F.fromList[row1,row2,row3,row4,row5,row6])end
 val transposedGradient=
   let fun row1(a,b,c)=F.cons(a,F.cons(zero,F.cons(zero,F.cons(add b c,F.cons(add(add a c)c,F.cons(add(add a b)b,F.empty()))))))
       fun row2(a,b,c)=F.cons(zero,F.cons(b,F.cons(zero,F.cons(add(add b c)c,F.cons(add a c,F.cons(add(add a a)b,F.empty()))))))
       fun row3(a,b,c)=F.cons(zero,F.cons(zero,F.cons(c,F.cons(add(add c b)b,F.cons(add(add c a)a,F.cons(add a b,F.empty()))))))
   in A.listArray(1,3)(F.fromList[row1,row2,row3])end

 val c4=number 4.0
 val c9=number(~9.0)
 val c11=number 11.0
 val c12=number 12.0
 val c16=number(~16.0)
 val c18=number(~18.0)
 val c20=number(~20.0)
 val c24=number 24.0
 val c32=number(~32.0)
 val c48=number(~48.0)
 val c78=number 78.0
 val c80=number 80.0
 val c96=number(~96.0)
 val c120=number 120.0
 val c128=number 128.0
 val c160=number 160.0
 val c192=number 192.0
 val c384=number 384.0
 val a11=(c78,c18,c18,(c24,c24),(c24,c120),(c24,c120))
 val a12=(c9,c9,c11,(c4,c16),(c4,c16),(c16,c16))
 val a13=(c9,c11,c9,(c16,c4),(c16,c16),(c4,c16))
 val a14=(c12,c20,c20,(c48,c48),(c48,c16),(c48,c16))
 val a15=((negative c48),c16,c32,(c32,c16),(c32,(negative c48)),(c16,(negative c48)))
 val a16=((negative c48),c32,c16,(c16,c32),(c16,(negative c48)),(c32,(negative c48)))
 val a22=(c18,c78,c18,(c24,c120),(c24,c24),(c120,c24))
 val a23=(c11,c9,c9,(c16,c16),(c16,c4),(c16,c4))
 val a24=(c16,(negative c48),c32,(c32,(negative c48)),(c32,c16),((negative c48),c16))
 val a25=(c20,c12,c20,(c48,c16),(c48,c48),(c16,c48))
 val a26=(c32,(negative c48),c16,(c16,(negative c48)),(c16,c32),((negative c48),c32))
 val a33=(c18,c18,c78,(c120,c24),(c120,c24),(c24,c24))
 val a34=(c16,c32,(negative c48),((negative c48),c32),((negative c48),c16),(c32,c16))
 val a35=(c32,c16,(negative c48),((negative c48),c16),((negative c48),c32),(c16,c32))
 val a36=(c20,c20,c12,(c16,c48),(c16,c48),(c48,c48))
 val a44=(c96,c160,c160,(c384,c384),(c384,c128),(c384,c128))
 val a45=((negative c16),(negative c16),c80,(c192,c128),(c192,c128),(c128,c128))
 val a46=((negative c16),c80,(negative c16),(c128,c192),(c128,c128),(c192,c128))
 val a55=(c160,c96,c160,(c384,c128),(c384,c384),(c128,c384))
 val a56=(c80,(negative c16),(negative c16),(c128,c128),(c128,c192),(c128,c192))
 val a66=(c160,c160,c96,(c128,c384),(c128,c384),(c384,c384))
 type convectionEntry=realv*realv*realv*(realv*realv)*(realv*realv)*(realv*realv)
 fun selectCoefficients(row:convectionEntry list)=
   let val values=F.fromList row
   in(map(fn v=> #1(force v))values,map(fn v=> #2(force v))values,
      map(fn v=> #3(force v))values,map(fn v=>cell(#4(force v)))values,
      map(fn v=>cell(#5(force v)))values,map(fn v=>cell(#6(force v)))values)end
 val convectionCoefficients=F.fromList[
   selectCoefficients[a11,a12,a13,a14,a15,a16],selectCoefficients[a12,a22,a23,a24,a25,a26],
   selectCoefficients[a13,a23,a33,a34,a35,a36],selectCoefficients[a14,a24,a34,a44,a45,a46],
   selectCoefficients[a15,a25,a35,a45,a55,a56],selectCoefficients[a16,a26,a36,a46,a56,a66]]
 val convectionMatrix=
   A.listArray(1,6)(map(fn cols=>let val(c1,c2,c3,c4,c5,c6)=force cols
       fun pairTerm g h x=let val(a,b)=force x in add(mul a g)(mul b h)end
       fun part(g1,g2,g3)velocity=
          map(fn col=>listMatchProd(force col)velocity)
            (F.fromList[map(mul g1)c1,map(mul g2)c2,map(mul g3)c3,
               map(pairTerm g2 g3)c4,map(pairTerm g1 g3)c5,map(pairTerm g1 g2)c6])
     in cell(fn(y1,y2)=>fn(u1,u2)=>zipWith add(part y1 u1)(part y2 u2))end)convectionCoefficients)
 fun member n values=case force values of F.Nil=>false
   |F.Cons(x,rest)=>force x=n orelse member n rest
 fun getRhs1(elementFactors:elementFactor A.array)table velocitySteer pressureSteer(pressure,(u1,u2))=
   let
     fun contribution entry=D.delay(fn()=>
       let val(e,id)=force entry
           val(det,factors as(fx,fy))=force(A.lookup elementFactors e)
           val gradient=force(A.lookup gradientMatrix id)
           val diffusion=force(A.lookup diffusionMatrix id)factors
           val velocity=(getValues u1(force(A.lookup velocitySteer e)),getValues u2(force(A.lookup velocitySteer e)))
           val pressures=getValues pressure(force(A.lookup pressureSteer e))
           val convection=force(A.lookup convectionMatrix id)factors velocity
           fun component values factor=mul
             (add(add(divide(listMatchProd values diffusion)(number(~3.0)))
                (divide(listMatchProd values convection)(number(~1260.0))))
                (divide(listMatchProd pressures(gradient factor))(number 3.0)))det
       in(component(#1 velocity)fx,component(#2 velocity)fy)end)
     val pairs=map(fn entries=>cell(map contribution(force entries)))(A.elements table)
     fun component select=A.listArray(A.bounds table)
       (map(fn row=>sum(map(fn p=>select(force p))(force row)))pairs)
   in(component #1,component #2)end
 fun getRhs2(elementFactors:elementFactor A.array)table velocitySteer pressureFixed(u1,u2)=
   let val bnds=A.bounds table
       fun row i=D.delay(fn()=>if member(force i)pressureFixed then 0.0 else
         force(divide(sum(map(fn entry=>D.delay(fn()=>
          let val(e,id)=force entry
              val steering=force(A.lookup velocitySteer e)
              val(det,factors as(fx,fy))=force(A.lookup elementFactors e)
              val gradient=force(A.lookup transposedGradient id)
          in force(mul(add(listMatchProd(getValues u1 steering)(gradient fx))
                    (listMatchProd(getValues u2 steering)(gradient fy)))det)end))
              (force(A.lookup table(force i)))))(number(~3.0))))
   in A.defListArray eq bnds zero(map row(range(#1 bnds)(#2 bnds)))end
 fun getRhs3(elementFactors:elementFactor A.array)table pressureSteer deltaPressure=
   let
     fun contribution entry=D.delay(fn()=>
       let val(e,id)=force entry val gradient=force(A.lookup gradientMatrix id)
           val pressures=getValues deltaPressure(force(A.lookup pressureSteer e))
           val(det,(fx,fy))=force(A.lookup elementFactors e)
       in(mul det(listMatchProd pressures(gradient fx)),mul det(listMatchProd pressures(gradient fy)))end)
     val pairs=map(fn entries=>cell(map contribution(force entries)))(A.elements table)
     fun component select=A.amap(fn x=>divide x(number 3.0))
       (A.listArray(A.bounds table)(map(fn row=>sum(map(fn p=>select(force p))(force row)))pairs))
   in(component #1,component #2)end
 fun sparseElements array=map(fn p=> #2(force p))(A.sparseAssociations array)
 fun jacobi step(elementFactors:elementFactor A.array)table velocitySteer(allBoundary,(xFixed,yFixed))(b1,b2)
       scalar maxIter iterTolerance relax=
   let val bnds=A.bounds table
       val initial=A.array bnds(F.empty())
       val diagonal=A.listArray bnds
         (map(fn i=>sum(map(fn entry=>let val(e,id)=force entry
           in mul(#1(force(A.lookup elementFactors e)))(A.lookup massRowSums id)end)
           (force(A.lookup table(force i)))))(range(#1 bnds)(#2 bnds)))
       fun iterate(old1,old2)n=
         let
           fun findDiff fixed x b=
             A.defListArray eq bnds zero
               (map(fn i=>D.delay(fn()=>if force(A.lookup fixed(force i))then 0.0 else
                 let val scaled=divide(A.lookup b(force i))scalar
                     val residual=D.delay(fn()=>if n=maxIter then force scaled else
                       force(sub scaled(sum(map(fn entry=>
                         let val(e,id)=force entry
                             val area= #1(force(A.lookup elementFactors e))
                             val row=map(mult area)(force(A.lookup massMatrix id))
                         in listInnerProd(getValues x(force(A.lookup velocitySteer e)))row end)
                          (force(A.lookup table(force i)))))))
                 in force(divide(mul residual relax)(A.lookup diagonal(force i)))end))
                (range(#1 bnds)(#2 bnds)))
           val diff=if step=1 then(findDiff xFixed old1 b1,findDiff yFixed old2 b2)
             else(findDiff allBoundary old1 b1,findDiff allBoundary old2 b2)
           val next=if n=maxIter then diff else addU(old1,old2)diff
           val finished=n<=1 orelse(n<>maxIter andalso
             lt(tolerance(F.append(A.elements(#1 next))(A.elements(#2 next)))
                  (F.append(sparseElements(#1 diff))(sparseElements(#2 diff)))true)iterTolerance)
         in if finished then next else iterate next(n-1)end
   in iterate(initial,initial)maxIter end
 fun mergeLine xs ys=F.defer(fn()=>case force xs of F.Nil=>F.append xs ys
   |F.Cons(x,xt)=>(case force ys of F.Nil=>F.append xs ys|F.Cons(y,yt)=>
      if force x=force y then F.cons(x,mergeLine xt yt)
      else if force x<force y then F.cons(x,mergeLine xt ys)
      else F.cons(y,mergeLine xs yt)))
 fun removeList xs ys=F.defer(fn()=>case force xs of F.Nil=>ys
   |F.Cons(x,xt)=>(case force ys of F.Nil=>ys|F.Cons(y,yt)=>
      if force x=force y then removeList xt yt
      else if force x<force y then removeList xt ys
      else F.cons(y,removeList xs yt)))
 fun mergeLines lines=case force lines of F.Nil=>raise Empty|F.Cons(x,rest)=>
   force(A.foldLeft(fn a=>fn b=>cell(mergeLine(force a)(force b)))x rest)
 fun equalIntLists a b=listEq intEq(force a)(force b)
 fun uniqueLists values=let
     fun memberList x seen=case force seen of F.Nil=>false|F.Cons(y,rest)=>
       equalIntLists x y orelse memberList x rest
     fun loop values seen=F.defer(fn()=>case force values of F.Nil=>F.empty()
       |F.Cons(x,rest)=>if memberList x seen then loop rest seen
         else F.cons(x,loop rest(F.cons(x,seen))))
   in loop values(F.empty())end
 fun minDegree oldRows=
   let
     fun appendLists a b=cell(F.append(force a)(force b))
     val initial=A.accumArray equalIntLists appendLists(cell(F.empty()))(A.bounds oldRows)
       (map(fn p=>let val(i,row)=force p in pair(length(force row))(cell(singleton(cell i)))end)
         (A.associations oldRows))
     fun find counts cliques processed result=
       let val remaining=A.sparseAssociations counts
       in if null remaining then result else
         let val(_,pivots)=force(head remaining) val pivot=force(head(force pivots))
             fun getCols index cliques=removeList processed
               (mergeLines(F.cons(A.lookup oldRows index,
                 F.filter(fn clique=>member index clique)cliques)))
             val newColumns=F.filter(fn value=>value<>pivot)(getCols pivot cliques)
             val done=mergeLine processed(singleton(cell pivot))
             val nextResult=F.append result(singleton(cell pivot))
             fun removeCliques values removed=case force values of F.Nil=>removed
               |F.Cons(clique,rest)=>
                 let val(left,right)=A.partition(fn n=>pivot<force n)(force clique)
                     val without=L.delay(fn()=>F.append left(tail right))
                     val keep=if null right orelse force(head right)<>pivot then true
                       else case force(L.force without)of F.Nil=>false|F.Cons(_,tail)=>not(null tail)
                 in removeCliques rest(if keep then F.cons(
                      if null right orelse force(head right)<>pivot then clique else cell(L.force without),removed)else removed)end
             val removed=removeCliques cliques(F.empty())
             val nextCliques=uniqueLists(F.cons(cell newColumns,removed))
             fun updateCounts values updates=case force values of F.Nil=>updates
               |F.Cons(r,rest)=>
                 let val count=length(getCols(force r)(F.cons(cell newColumns,cliques)))-1
                 in updateCounts rest(F.cons(pair count(cell(singleton r)),updates))end
             val updates=updateCounts newColumns(F.empty())
             val changed=mergeLines(F.cons(cell(singleton(cell pivot)),
               map(fn p=> #2(force p))updates))
             val oldCounts=map(fn p=>let val(i,rows)=force p
               in pair i(cell(removeList changed(force rows)))end)(A.sparseAssociations counts)
             val nextCounts=A.accumArray equalIntLists
               (fn a=>fn b=>cell(mergeLine(force a)(force b)))(cell(F.empty()))(A.bounds counts)
               (F.append oldCounts updates)
         in find nextCounts nextCliques done nextResult end
       end
   in find initial(F.empty())(F.empty())(F.empty())end
 type realArray=real A.array
 type segment=int*real F.seq
 type block=realArray*segment A.array
 fun unusedEq _ _=raise Fail"unexpected equality on an array with no default"
 fun appendSequences a b=cell(F.append(force a)(force b))
 fun boolEq a b=force a=force b
 fun dropWhile predicate values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then dropWhile predicate rest else values)
 fun init values=F.defer(fn()=>case force values of F.Nil=>raise Empty|F.Cons(x,rest)=>
   if null rest then F.empty()else F.cons(x,init rest))
 fun segmentEq a b=let val(i,xs)=force a val(j,ys)=force b
   in i=j andalso listEq eq xs ys end
 val pressureElementMatrix=
   let
     fun entry p q(area,(a,b))=
       let fun nth(a,b,c)index=case index of 1=>a|2=>b|_=>c
       in mul(ff1(nth a p)(nth a q)(nth b p)(nth b q))area end
     val rows=List.tabulate(3,fn p=>A.listArray(1,3)
       (F.fromList(List.tabulate(3,fn q=>entry(p+1)(q+1)))))
   in A.listArray(1,3)(F.fromList rows)end
 fun orderedMatrix total(elementFactors:elementFactor A.array)pressureSteer fixed=
   let
     val bnds=(1,total) val extended=(0,total)
     fun intListEq a b=listEq intEq(force a)(force b)
     fun realAssociationEq a b=let val(i,x)=force a val(j,y)=force b in i=j andalso eq x y end
     fun realAssociationsEq a b=listEq realAssociationEq(force a)(force b)
     val contributions=A.flatMap(fn e=>
       let val factors=A.lookup elementFactors(force e)
           val pairs=A.zip(range 1 3)(force(A.lookup pressureSteer(force e)))
       in A.flatMap(fn entry=>let val(ii,i)=force entry
             val row=force(A.lookup pressureElementMatrix(force ii))
           in map(fn column=>let val(jj,j)=force column
               val value=D.delay(fn()=>force(force(A.lookup row(force jj))(force factors)))
             in pair(force i)(cell(singleton(pair(force j)value)))end)
               (F.filter(fn(_,j)=>force j<=force i)pairs)end)pairs end)
       (range(#1(A.bounds elementFactors))(#2(A.bounds elementFactors)))
     val temporary=A.accumArray realAssociationsEq appendSequences(cell(F.empty()))bnds contributions
     val assembled=A.listArray bnds(map(fn i=>cell(A.accumArray eq add zero(1,force i)
       (force(A.lookup temporary(force i)))))(range 1 total))
     val oldMatrix=A.update unusedEq assembled(map(fn i=>D.delay(fn()=>
       let val row=force(A.lookup assembled(force i))
           val revised=A.update eq row(singleton(pair(force i)(mul(A.lookup row(force i))large)))
       in(force i,cell revised)end))fixed)
     val oldRows=A.accumArray intListEq appendSequences(cell(F.empty()))bnds
       (A.flatMap(fn i=>let
           val indices=map(fn entry=>cell(#1(force entry)))(A.sparseAssociations(force(A.lookup oldMatrix(force i))))
           val mirror=map(fn j=>pair(force j)(cell(singleton i)))(F.filter(fn j=>force i<>j)indices)
         in F.cons(pair(force i)(cell indices),mirror)end)(range 1 total))
     fun inverse mapping=A.array extended(map(fn entry=>let val(i,j)=force entry
       in pair(force j)(cell i)end)(A.associations mapping))
     val minToOld=A.listArray extended(F.cons(cell 0,minDegree oldRows))
     val oldToMin=inverse minToOld
     fun getColumns oldIndex mapping=
       let val i=A.lookup mapping oldIndex
       in F.filter(fn j=>j<=force i)
          (map(fn j=>A.lookup mapping(force j))(force(A.lookup oldRows oldIndex)))end
     fun children tree=A.accumArray intListEq appendSequences(cell(F.empty()))extended
       (map(fn entry=>let val(i,j)=force entry in pair(force j)(cell(singleton(cell i)))end)(A.associations tree))
     fun allRows i ancestors parents=if i>total then parents else
       let
         fun root k old=let val next=force(A.lookup old k)
           in if next=0 orelse next=i then(k,old)
             else root next(A.update intEq old(singleton(pair k(cell i))))end
         fun connections values result=case force values of F.Nil=>result|F.Cons(k,rest)=>
           let val(rs,ancestors)=result val(r,revised)=root(force k)ancestors
               val newParent=pair r(cell i)
               val next=if force(A.lookup revised r)<>0 then(rs,revised)
                 else(F.cons(newParent,rs),A.update intEq revised(singleton newParent))
           in connections rest next end
         val(rss,revised)=connections
           (F.filter(fn k=>k<>i)(getColumns(force(A.lookup minToOld i))oldToMin))
           (F.empty(),ancestors)
       in F.append(allRows(i+1)revised parents)rss end
     val minimumTree=A.defArray intEq bnds(cell 0)
       (allRows 1(A.defArray intEq bnds(cell 0)(F.empty()))(F.empty()))
     val childTable=children minimumTree
     fun postorder result values=case force values of F.Nil=>result|F.Cons(r,rest)=>
       let val(reorder,label)=postorder result(force(A.lookup childTable(force r)))
       in postorder(F.cons(pair(force r)(cell label),reorder),label+1)rest end
     val minToNew=A.array extended(F.cons(pair 0(cell 0),#1(postorder(F.empty(),1)(force(A.lookup childTable 0)))))
     val oldToNew=A.amap(fn i=>A.lookup minToNew(force i))oldToMin
     val newToOld=inverse oldToNew
     val newTree=A.array bnds(map(fn entry=>let val(i,j)=force entry
       in pair(force(A.lookup minToNew i))(A.lookup minToNew(force j))end)(A.associations minimumTree))
     val blockEnds=map(fn entry=>cell(#1(force entry)))
       (F.filter(fn(i,j)=>force j<>i+1)(A.associations newTree))
     val blockBounds=A.zip(F.cons(cell 1,map(fn i=>cell(force i+1))(init blockEnds)))blockEnds
     fun getValue i j=D.delay(fn()=>
       let val oldI=force(A.lookup newToOld i) val oldJ=force(A.lookup newToOld j)
       in if oldI<oldJ then force(A.lookup(force(A.lookup oldMatrix oldJ))oldI)
         else force(A.lookup(force(A.lookup oldMatrix oldI))oldJ)end)
     fun findNonzero i=
       let fun walk j flags=if j>i orelse j=0 orelse force(A.lookup flags j)then flags
             else walk(force(A.lookup newTree j))(A.update boolEq flags(singleton(pair j(cell true))))
           fun loop values flags=case force values of F.Nil=>flags|F.Cons(j,rest)=>loop rest(walk(force j)flags)
       in loop(getColumns(force(A.lookup newToOld i))oldToNew)(A.defArray boolEq(1,i)(cell false)(F.empty()))end
     fun firstNonzero(lo,hi)flags=
       let fun loop j=if j>hi orelse force(A.lookup flags j)then j else loop(j+1)
       in loop lo end
     val initial=A.listArray(1,length blockEnds)(map(fn bounds=>D.delay(fn()=>
       let val(lo,hi)=let val(a,b)=force bounds in(force a,force b)end
           val diagonal=A.listArray(lo,hi)(map(fn i=>getValue(force i)(force i))(range lo hi))
           val nonempty=F.filter(fn(_,j)=>j<=hi)
             (map(fn i=>pair(force i)(firstNonzero(lo,hi)(findNonzero(force i))))(range(lo+1)total))
           val off=A.defArray segmentEq(lo+1,total)(cell(hi+1,F.empty()))
             (map(fn entry=>let val(i,j)=force entry
               in pair i(cell(j,map(fn column=>getValue i(force column))(range j(Int.min(hi,i-1)))))end)nonempty)
       in(diagonal,off)end))blockBounds)
   in(initial,oldToNew)end
 (* Input control has memoized character spines independent of finite data policy. *)
 fun nthCell values n=if n=0 then head values else nthCell(tail values)(n-1)
 type chars=char C.seq
 type 'a reader=chars->('a D.t*chars)L.delay
 fun input s=C.fromList(String.explode s)
 fun charsString values=String.implode(C.toList values)
 fun uncons values=case L.force values of C.Nil=>NONE|C.Cons(x,rest)=>SOME(L.force x,rest)
 fun dropChars predicate values=C.defer(fn()=>case uncons values of NONE=>C.empty()
   |SOME(c,rest)=>if predicate c then dropChars predicate rest else values)
 fun spanChars predicate values=case uncons values of NONE=>(C.empty(),C.empty())
   |SOME(c,rest)=>if predicate c then
       let val split=L.delay(fn()=>spanChars predicate rest)
       in(C.cons(L.delay(fn()=>c),C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
      else(C.empty(),values)
 fun skipLines 0 values=values
   |skipLines n values=C.defer(fn()=>case uncons(dropChars(fn c=>c<> #"\n")values)of
      NONE=>C.empty()|SOME(_,rest)=>skipLines(n-1)rest)
 fun textWords values=C.defer(fn()=>let val start=dropChars Char.isSpace values
   in case uncons start of NONE=>C.empty()|SOME _=>
      let val(word,rest)=spanChars(not o Char.isSpace)start
      in C.cons(L.delay(fn()=>word),textWords rest)end end)
 fun wordAt n values=case L.force(C.drop n(textWords values))of
   C.Nil=>raise Empty|C.Cons(word,_)=>L.force word
 fun normalizeNumber s=String.map(fn #"-"=> #"~"|c=>c)s
 fun scanNumber floating values=
   let val start=dropChars Char.isSpace values
       val(sign,start)=case uncons start of SOME(#"-",rest)=>("-",rest)
         |SOME(#"+",rest)=>("+",rest)|_=>("",start)
       val(whole,afterWhole)=spanChars Char.isDigit start
       val(raw,afterFraction)=if floating then(case uncons afterWhole of
         SOME(#".",rest)=>let val(frac,after)=spanChars Char.isDigit rest
           in(sign^charsString whole^"."^charsString frac,after)end
        |_=> (sign^charsString whole,afterWhole))else(sign^charsString whole,afterWhole)
       val(raw,afterExponent)=if floating then(case uncons afterFraction of
         SOME(c,rest)=>if c= #"e"orelse c= #"E"then
           let val(sign,rest)=case uncons rest of SOME(#"-",r)=>("-",r)|SOME(#"+",r)=>("+",r)|_=>("",rest)
               val(digits,after)=spanChars Char.isDigit rest
           in(raw^"e"^sign^charsString digits,after)end else(raw,afterFraction)
        |_=> (raw,afterFraction))else(raw,afterFraction)
       val _=if raw=""orelse raw="-"orelse raw="+"then raise Fail"Prelude.read: no parse"else()
   in(raw,afterExponent)end
 fun readInt values=L.delay(fn()=>let val(raw,rest)=scanNumber false values
       val value=D.delay(fn()=>case Int.fromString(normalizeNumber raw)of
         SOME i=>i|NONE=>raise Fail"Prelude.read: no integer parse")
   in(value,rest)end)
 fun readFloat values=L.delay(fn()=>let val(raw,rest)=scanNumber true values
       val value=D.delay(fn()=>case Real.fromString(normalizeNumber raw)of
         SOME r=>R.round r|NONE=>raise Fail"Prelude.read: no Float parse")
   in(value,rest)end)
 fun readPair(first:'a reader)(second:'b reader)values=L.delay(fn()=>
   let val a=first values val b=second(C.defer(fn()=> #2(L.force a)))
   in(D.delay(fn()=>(#1(L.force a),#1(L.force b))),C.defer(fn()=> #2(L.force b)))end)
 (* The source deliberately parses independently for takeval and dropval. *)
 fun readN(reader:'a reader)n values=
   let fun take 0 values=F.empty()
         |take n values=F.defer(fn()=>let val next=reader values
           in F.cons(#1(L.force next),take(n-1)(C.defer(fn()=> #2(L.force next))))end)
       fun drop n values=C.defer(fn()=>case uncons values of NONE=>C.empty()
         |SOME _=>if n=0 then values else drop(n-1)(#2(L.force(reader values))))
   in(take n values,drop n values)end
 fun readNReader reader n values=L.delay(fn()=>let val(values,rest)=readN reader n values
   in(cell values,rest)end)
 fun firstChars values=case uncons values of SOME(c,_)=>c|NONE=>raise Empty
 type config=bool*int*realv*int*realv*realv*realv
 fun readConfig source:string*config=
   let val header=skipLines 1 source
       val pad=readInt header
       val start=skipLines(force(#1(L.force pad))+2)(C.defer(fn()=> #2(L.force pad)))
       val monitoring=firstChars(wordAt 9 start)= #"t"
       val numeric=skipLines(force(#1(L.force pad))+14)(C.defer(fn()=> #2(L.force pad)))
       val(ints,rest1)=readN readInt 2 numeric
       val(floats,rest2)=readN readFloat 3 rest1
       val time=readFloat(skipLines 2 rest2)
       val file=charsString(wordAt 5(skipLines 11(C.defer(fn()=> #2(L.force time)))))
   in(file,(monitoring,force(head ints),head floats,
       force(head(tail ints)),head(tail floats),head(tail(tail floats)),#1(L.force time)))end
 type mesh={elements:int,nodes:int,pressureNodes:int,velocitySteer:int F.seq A.array,
   pressureSteer:int F.seq A.array,coordinates:(realv*realv)A.array,
   initial:realArray*(realArray*realArray),
   boundary:bool A.array*(bool A.array*bool A.array),fixed:int F.seq}
 fun readMesh source:mesh=
   let val header=readInt(skipLines 1 source)
       val start=skipLines(force(#1(L.force header))+4)(C.defer(fn()=> #2(L.force header)))
       val(counts,rest1)=readN readInt 6 start
       val elements=force(head counts) val nodes=force(head(tail counts))
       val boundaryCount=force(head(tail(tail counts)))
       val pressureNodes=force(nthCell counts 5)
       val(velocityRows,rest3)=readN(readNReader readInt 8)elements(skipLines 2 rest1)
       val(coordinateRows,rest5)=readN(readPair readInt(readNReader readFloat 2))nodes(skipLines 2 rest3)
       val rest6=skipLines 2 rest5
       val(line,_)=spanChars(fn c=>c<> #"\n")rest6
       val width=List.length(C.toList(textWords line))-1
       val(initialRows,rest7)=readN(readPair readInt(readNReader readFloat width))nodes rest6
       val(boundaryRows,_)=readN(readPair readInt(readNReader(readPair readInt readFloat)width))boundaryCount(skipLines 2 rest7)
       fun steering takeCount=
         A.array(1,elements)(map(fn row=>let val fields=force row
              val chosen=if takeCount=8 then fields else F.take takeCount fields
           in pair(force(head chosen))(cell(tail(tail chosen)))end)velocityRows)
       val velocitySteer=steering 8 val pressureSteer=steering 5
       val coordinates=A.array(1,nodes)(map(fn row=>let val(i,xy)=force row val values=force xy
         in pair(force i)(pair(head values)(head(tail values)))end)coordinateRows)
       val initialVelocities=map(fn row=>let val(i,values)=force row val values=force values
         in pair(force i)(pair(head values)(head(tail values)))end)initialRows
       val boundaryValues=map(fn row=>let val(i,values)=force row val values=force values
         in pair(force i)(pair(#2(force(head values)))(#2(force(head(tail values)))))end)boundaryRows
       fun fixedNodes column=A.defArray boolEq(1,nodes)(cell false)
         (map(fn row=>let val(i,_)=force row in pair(force i)(cell true)end)
          (F.filter(fn(_,values)=>force(#1(force(nthCell(force values)column)))=1)boundaryRows))
       val xFixed=fixedNodes 0 val yFixed=fixedNodes 1
       val allBoundary=A.defArray boolEq(1,nodes)(cell false)
         (map(fn row=>pair(force(#1(force row)))(cell true))boundaryRows)
       fun pressureCondition row=
         let val(_,values)=row val values=force values val index=if width=5 then 3 else 2
         val(flag,_)=force(nthCell values index)
         in force flag=1 end
       val pressureConditions=map(fn row=>let val(i,values)=force row val index=if width=5 then 3 else 2
         in pair(force i)(#2(force(nthCell(force values)index)))end)
          (F.filter pressureCondition boundaryRows)
       val fixed=map(fn row=>cell(#1(force row)))pressureConditions
       fun velocity component fixedArray=A.defArray eq(1,nodes)zero(map(fn row=>
         let val(i,value)=force row
             val result=D.delay(fn()=>if force(A.lookup fixedArray i)then
                  force(component(force(#2(force(head(dropWhile(fn p=> #1(force p)<>i)boundaryValues))))))
                else force(component(force value)))
         in pair i result end)initialVelocities)
       val initialU=(velocity #1 xFixed,velocity #2 yFixed)
       val initialP=A.defArray eq(1,pressureNodes)zero
         (map(fn row=>let val(i,values)=force row val i=force i
             val result=D.delay(fn()=>if member i fixed then
                 force(#2(force(head(dropWhile(fn p=> #1(force p)<>i)pressureConditions))))
               else force(nthCell(force values)(if width=5 then 3 else 2)))
           in pair i result end)(F.filter(fn(i,_)=>force i<=pressureNodes)initialRows))
   in{elements=elements,nodes=nodes,pressureNodes=pressureNodes,
      velocitySteer=velocitySteer,pressureSteer=pressureSteer,coordinates=coordinates,
      initial=(initialP,initialU),boundary=(allBoundary,(xFixed,yFixed)),fixed=fixed}end
 fun calOneElement(start,values)(_,segment)old=D.delay(fn()=>
   let val(other,rest)=force segment
   in if null rest then force old else
     let val maximum=Int.max(other,start)
     in force(sub old(listInnerProd(F.drop(maximum-other)rest)(F.drop(maximum-start)values)))end end)
 fun calOneSegment segments(old,off)=F.defer(fn()=>if null segments then F.empty()else
   let val(_,values)=force old val off=force off
   in zipWith(fn segment=>fn old=>calOneElement off(force segment)old)segments values end)
 fun matchPairs xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,xt)=>(case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>
      let val(i,a)=force x val(j,b)=force y
      in if i<j then matchPairs xt ys else if j<i then matchPairs xs yt
        else F.cons(pair i(cell(a,b)),matchPairs xt yt)end))
 fun cholesky(initial:block A.array)=
   let
     fun factor old index=
       let val j=force index
           val current=A.lookup old j
           val bnds=A.bounds(#1(force current)) val(lo,hi)=bnds
           fun previous k=D.delay(fn()=>
             let val off= #2(force(A.lookup old(force k)))
             in(force k,cell(F.filter(fn(i,_)=>lo<=i andalso i<=hi)(A.associations off)))end)
           val predecessors=map previous(range 1(j-1))
           fun update block previous=D.delay(fn()=>
             let val(diag,off)=force block val(k,segments)=force previous val segments=force segments
                 val newDiagonal=A.accum eq sub diag
                   (map(fn segment=>let val(i,value)=force segment val(_,vs)=force value
                     in pair i(listInnerProd vs vs)end)
                    (F.filter(fn(_,segment)=>not(null(#2(force segment))))segments))
                 val pairs=matchPairs(A.sparseAssociations off)
                   (A.sparseAssociations(#2(force(A.lookup old k))))
                 val newOff=A.update segmentEq off(map(fn entry=>
                   let val(i,matched)=force entry val(a,b)=force matched
                       val(start,_)=force a
                   in pair i(cell(start,calOneSegment(F.drop(start-lo)segments)(a,b)))end)pairs)
             in(newDiagonal,newOff)end)
           val first=A.foldLeft update current predecessors
           val result=L.delay(fn()=>
             let val(diag,off)=force first
                 fun build entries(diagonal,offsets)=case force entries of F.Nil=>(diagonal,offsets)
                   |F.Cons(entry,rest)=>
                     let val(i,value)=force entry val(start,values)=force value
                         fun scan oldValues diags segments accumulated=case force oldValues of F.Nil=>accumulated
                           |F.Cons(old,ot)=>(case force diags of F.Nil=>accumulated|F.Cons(d,dt)=>
                             case force segments of F.Nil=>accumulated|F.Cons(segment,st)=>
                               let val next=divide(calOneElement(start,accumulated)(force segment)old)d
                               in scan ot dt st(F.append accumulated(singleton next))end)
                         val newOff=scan values(F.drop(start-lo)diagonal)(F.drop(start-lo)offsets)(F.empty())
                         fun newDiagonal()=sqrt(sub(A.lookup diag i)(listInnerProd newOff newOff))
                         val nextOffsets=F.append offsets(singleton(pair i(cell(start,newOff))))
                     in build rest(if i<=hi then F.append diagonal(singleton(newDiagonal()))else diagonal,nextOffsets)end
             in build(A.sparseAssociations off)
                 (singleton(sqrt(A.lookup diag lo)),singleton(pair lo(cell(lo+1,F.empty()))))end)
           val diagonal=A.listArray bnds(F.defer(fn()=> #1(L.force result)))
           val off=A.update segmentEq(#2(force first))(tail(F.defer(fn()=> #2(L.force result))))
       in A.update unusedEq old(singleton(pair j(cell(diagonal,off))))end
     val result=A.foldLeft(fn old=>fn index=>cell(factor(force old)index))(cell initial)
       (range(#1(A.bounds initial))(#2(A.bounds initial)))
   in force result end
 fun lowerPart upper off=dropWhile(fn p=> #1(force p)<=upper)(A.sparseAssociations off)
 fun forwardSubstitution(factors:block A.array)b=
   let val upper= #2(A.bounds factors)
       fun loop block b result=if block>upper then result else
         let val(diag,off)=force(A.lookup factors block)
             val(lo,hi)=A.bounds diag
             fun solve i result=if i>hi then result else
               let val(start,values)=force(A.lookup off i)
                   val next=divide(sub(A.lookup b i)
                     (listInnerProd(F.drop(start-lo)result)values))(A.lookup diag i)
               in solve(i+1)(F.append result(singleton next))end
             val next=solve(lo+1)(singleton(divide(A.lookup b lo)(A.lookup diag lo)))
             val revised=A.accum eq sub b(map(fn entry=>
               let val(index,segment)=force entry val(start,values)=force segment
               in pair index(listInnerProd(F.drop(start-lo)next)values)end)(lowerPart hi off))
         in loop(block+1)revised(F.append result next)end
   in A.listArray(A.bounds b)(loop 1 b(F.empty()))end
 fun backwardSubstitution(factors:block A.array)y=
   let val upper= #2(A.bounds factors)
       fun loop block result=if block<1 then result else
         let val(diag,off)=force(A.lookup factors block)
             val bnds as(lo,hi)=A.bounds diag
             val changes=A.flatMap(fn entry=>let val(index,segment)=force entry
                 val(start,values)=force segment
               in zipWith(fn i=>fn v=>pair(force i)v)(range start hi)
                    (map(fn v=>mul(A.lookup result index)v)values)end)(lowerPart hi off)
             val b=A.accum eq sub(A.listArray bnds(map(fn i=>A.lookup y(force i))(range lo hi)))changes
             fun solve i bRoot result=if i<lo then result else
               let val b=L.force bRoot
                   val next=divide(A.lookup b i)(A.lookup diag i)
                   val revised=L.delay(fn()=>let val(start,values)=force(A.lookup off i)
                     val changes=zipWith(fn i=>fn v=>pair(force i)v)(range start(i-1))(map(mul next)values)
                     in A.accum eq sub b changes end)
               in solve(i-1)revised(A.update eq result(singleton(pair i next)))end
         in loop(block-1)(solve hi(L.delay(fn()=>b))result)end
   in loop upper(A.array(A.bounds y)(F.empty()))end
 fun choleskyMethod(factors:block A.array,mapping:int A.array)(b:realArray)scalar=
   let val bnds=A.bounds b
       val revised=A.array bnds(map(fn entry=>let val(i,v)=force entry
         in pair(force(A.lookup mapping i))v end)(A.associations b))
       val x=backwardSubstitution factors(forwardSubstitution factors revised)
   in A.amap(fn x=>mul x scalar)(A.ixmap bnds(fn i=>force(A.lookup mapping i))x)end
 type 'a normalPack='a L.delay*bool L.delay
 fun andAnd a b=if a then if b()then true else raise Fail"andAnd: 2nd argument not True"
   else raise Fail"andAnd: first argument not True\n"
 fun normalReal value=let val x=force value in if Real.==(x,0.0)then true else true end
 fun normalArray normal a=
   let val A.Array(_,_,default,trie)=L.force a
       fun node trie=case L.force trie of A.Null=>true|A.Leaf value=>normal value
          |A.Fork(left,right)=>andAnd(node left)(fn()=>node right)
       val default=case default of NONE=>true|SOME value=>normal value
   in andAnd default(fn()=>node trie)end
 fun normalVelocity(x,y)=andAnd(normalArray normalReal x)(fn()=>normalArray normalReal y)
 fun pack normal thunk=let val root=L.delay thunk
   in(root,L.delay(fn()=>normal(L.force root)))end
 fun normalize(_,flag)=L.force flag
 fun retrieve(root,_)=L.force root
 fun chars s=C.fromList(String.explode s)
 structure B=struct
   type builder=chars->chars
   fun id rest=rest
   fun str s rest=C.append(chars s)rest
   fun cat a b rest=a(C.defer(fn()=>b rest))
   fun pieces []=id|pieces(x::xs)=cat x(pieces xs)
   fun delayed f rest=C.defer(fn()=>f()rest)
   fun output b=b(C.empty())
 end
 fun signed n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun showReal value=B.delayed(fn()=>B.str(BenchFluidFloatShow.show(force value)))
 fun showList printer values=B.delayed(fn()=>
   let fun loop values=B.delayed(fn()=>case force values of F.Nil=>B.id
       |F.Cons(x,rest)=>B.cat(printer x)(B.delayed(fn()=>if null rest then B.id
            else B.cat(B.str",")(loop rest))))
   in B.pieces[B.str"[",loop values,B.str"]"]end)
 fun showRealArray a=B.delayed(fn()=>let val(lo,hi)=A.bounds a
       fun entry p=B.delayed(fn()=>let val(i,v)=force p
         in B.pieces[B.str"(",B.str(signed i),B.str",",showReal v,B.str")"]end)
   in B.pieces[B.str"array (",B.str(signed lo),B.str",",B.str(signed hi),B.str") ",
      showList entry(A.associations a)]end)
 fun showVelocities(a,b)=B.pieces[B.str"(",showRealArray a,B.str",",showRealArray b,B.str")"]
 fun hash chars=let fun loop h chars=case L.force chars of C.Nil=>h
     |C.Cons(c,rest)=>loop(Word64.+(Word64.*(h,0w31),Word64.fromInt(Char.ord(L.force c))))rest
   in loop 0w0 chars end
 fun outputString chars=String.implode(C.toList chars)
 fun simulate(mon,maxIter,iterTolerance,maxJacobi,jacobiTolerance,relax,time)
       elementFactors velocityAssembly pressureAssembly velocitySteer pressureSteer
       boundary pressureFixed factors(initialPressure,initialVelocity)=
   let
     fun iterate n oldP oldU result=
       let
         val rhs1a=L.delay(fn()=>if normalize oldP andalso normalize oldU then
           getRhs1 elementFactors velocityAssembly velocitySteer pressureSteer(retrieve oldP,retrieve oldU)
           else raise Match)
         val u1a=pack normalVelocity(fn()=>addU(retrieve oldU)
           (jacobi 1 elementFactors velocityAssembly velocitySteer boundary(L.force rhs1a)
             (divide(number 2.0)time)maxJacobi jacobiTolerance relax))
         val rhs1b=L.delay(fn()=>if normalize u1a then
           getRhs1 elementFactors velocityAssembly velocitySteer pressureSteer(retrieve oldP,retrieve u1a)
           else raise Match)
         val u1b=pack normalVelocity(fn()=>addU(retrieve oldU)
           (jacobi 1 elementFactors velocityAssembly velocitySteer boundary(L.force rhs1b)
             (divide one time)maxJacobi jacobiTolerance relax))
         val rhs2=pack(normalArray normalReal)(fn()=>if normalize u1b then
           getRhs2 elementFactors pressureAssembly velocitySteer pressureFixed(retrieve u1b)else raise Match)
         val deltaP=pack(normalArray normalReal)(fn()=>if normalize rhs2 then
           choleskyMethod factors(retrieve rhs2)(divide(number 2.0)time)else raise Match)
         val newP=pack(normalArray normalReal)(fn()=>addMat(retrieve oldP)(retrieve deltaP))
         val rhs3=L.delay(fn()=>if normalize deltaP then
           getRhs3 elementFactors velocityAssembly pressureSteer(retrieve deltaP)else raise Match)
         val newU=pack normalVelocity(fn()=>addU(retrieve u1b)
           (jacobi 3 elementFactors velocityAssembly velocitySteer boundary(L.force rhs3)
             (divide(number 2.0)time)maxJacobi jacobiTolerance relax))
         fun difference a b=zipWith sub(A.elements a)(A.elements b)
         val toleranceU=L.delay(fn()=>
           if normalize newU andalso normalize oldU then
             let val(x,y)=retrieve newU val(a,b)=retrieve oldU
             in tolerance(F.append(A.elements x)(A.elements y))
                  (F.append(difference x a)(difference y b))false end else raise Match)
         val toleranceP=L.delay(fn()=>if normalize newP andalso normalize oldP then
             tolerance(A.elements(retrieve newP))(difference(retrieve newP)(retrieve oldP))false else raise Match)
         val maximum=L.delay(fn()=>D.delay(fn()=>let val a=force(L.force toleranceU)val b=force(L.force toleranceP)
           in if a<=b then b else a end))
         val prefix=B.pieces[B.str"at time step ",B.str(signed(maxIter-n+1)),B.str":\n\n"]
         val monitor=if mon then B.pieces[
            B.str"initial presure:\n",B.delayed(fn()=>showRealArray(retrieve oldP)),B.str"\n",
            B.str"inititial velocities:\n",B.delayed(fn()=>showVelocities(retrieve oldU)),B.str"\n",
            B.str"rh1a:\n",B.delayed(fn()=>showVelocities(L.force rhs1a)),B.str"\n",
            B.str"velocities after the 1st half of step 1:\n",B.delayed(fn()=>showVelocities(retrieve u1a)),B.str"\n",
            B.str"rh1b:\n",B.delayed(fn()=>showVelocities(L.force rhs1b)),B.str"\n",
            B.str"velocities after the 2nd half of step 1:\n",B.delayed(fn()=>showVelocities(retrieve u1b)),B.str"\n",
            B.str"rh2:\n",B.delayed(fn()=>showRealArray(retrieve rhs2)),B.str"\n",
            B.str"rh3:\n",B.delayed(fn()=>showVelocities(L.force rhs3)),B.str"\n"]else B.id
         val revised=C.append result(B.output(B.cat prefix monitor))
         val final=B.output(B.pieces[B.str"presure:\n",B.delayed(fn()=>showRealArray(retrieve newP)),
           B.str"\nvelocities:\n",B.delayed(fn()=>showVelocities(retrieve newU)),B.str"\n"])
       in if n<=1 orelse lt(L.force maximum)iterTolerance then C.append revised final
          else if lt large(L.force maximum) then raise Fail"main iteration: overflow!"
          else iterate(n-1)newP newU revised end
   in iterate maxIter(pack(normalArray normalReal)(fn()=>initialPressure))
       (pack normalVelocity(fn()=>initialVelocity))(C.empty())end
 fun run config(mesh:mesh)=
   let fun delayedArray f=L.delay(fn()=>L.force(f()))
       val factors=delayedArray(fn()=>elementFactors(#elements mesh)(#coordinates mesh)(#pressureSteer mesh))
       val ordered=L.delay(fn()=>orderedMatrix(#pressureNodes mesh)factors(#pressureSteer mesh)(#fixed mesh))
       val factored=delayedArray(fn()=>cholesky(#1(L.force ordered)))
       val mapping=delayedArray(fn()=> #2(L.force ordered))
       val pressureTable=delayedArray(fn()=>getAssemblyTable(#pressureNodes mesh)(#elements mesh)3(#pressureSteer mesh))
       val velocityTable=delayedArray(fn()=>getAssemblyTable(#nodes mesh)(#elements mesh)6(#velocitySteer mesh))
   in simulate config factors velocityTable pressureTable(#velocitySteer mesh)(#pressureSteer mesh)
        (#boundary mesh)(#fixed mesh)(factored,mapping)(#initial mesh)end
end
