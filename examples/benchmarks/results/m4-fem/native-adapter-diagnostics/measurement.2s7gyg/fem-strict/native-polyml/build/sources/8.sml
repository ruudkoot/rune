(* Finite-element truss analysis from nofib real/fem. Every real operation
 * below follows source Float/binary32 grouping. *)
functor BenchFemFn(val strict:bool)=
struct
 structure A=BenchFemArraysFn(val strict=strict)
 structure L=BenchLazy
 structure R=BenchFemFloat
 datatype database=DB of int A.store*real A.store
 fun ints(DB(a,_))=a
 fun reals(DB(_,a))=a
 fun intAt db i=A.sub(ints db)i
 fun realAt db i=A.sub(reals db)i
 fun digit c=if c>= #"0"andalso c<= #"8"then Char.ord c-Char.ord #"0"else 9
 fun integer text=
   let val chars=String.explode text
       val(negative,body)=case chars of #"-"::rest=>(true,rest)| #"+"::rest=>(false,rest)|_=>(false,chars)
       val value=List.foldl(fn(c,n)=>n*10+digit c)0 body
   in if negative then ~value else value end
 fun digits chars=List.foldl(fn(c,n)=>R.add(R.mul(n,10.0),Real.fromInt(digit c)))0.0 chars
 fun powerTen 0=1.0|powerTen n=R.mul(10.0,powerTen(n-1))
 fun floating text=
   let val chars=String.explode text
       val(negative,body)=case chars of #"-"::rest=>(true,rest)| #"+"::rest=>(false,rest)|_=>(false,chars)
       fun split [] whole=(List.rev whole,[])
         |split(c::rest)whole=if Char.isDigit c then split rest(c::whole)else(List.rev whole,rest)
       val(whole,fraction)=split body[]
       val value=R.add(digits whole,R.divide(digits fraction,powerTen(List.length fraction)))
   in if negative then R.mul(~1.0,value)else value end
 fun database text=
   let val words=String.tokens Char.isSpace text
       fun intValues []=[]|intValues(word::rest)=
          if String.isSubstring"."word then intValues rest else L.delay(fn()=>integer word)::intValues rest
       fun realValues []=[]|realValues(word::rest)=
          if String.isSubstring"."word then L.delay(fn()=>floating word)::realValues rest else realValues rest
   in DB(A.delayedListArray 0(intValues words),A.delayedListArray 0(realValues words))end
 fun nnode db=intAt db 0
 fun nelem db=intAt db 1
 fun nmats db=intAt db 2
 fun nplds db=intAt db 3
 fun nodeXY db node=
   let val index=(node-1)*2 in(realAt db index,realAt db(index+1))end
 fun nodeBC db node=intAt db(3+node)
 fun material db m=
   let val index=nnode db*2+(m-1)*2 in(realAt db index,realAt db(index+1))end
 fun elementNodes db element=
   let val index=4+nnode db+(element-1)*3 in(intAt db index,intAt db(index+1))end
 fun elementMaterial db element=intAt db(3+nnode db+element*3)
 fun pointLoad db point=
   let val indexI=4+nnode db+nelem db*3+point-1
       val indexR=nnode db*2+nmats db*2+(point-1)*3
   in(intAt db indexI,realAt db indexR,realAt db(indexR+1),realAt db(indexR+2))end
 fun degreesAndCount db=
   let fun one(node,(count,values))=
          let val bc=nodeBC db node
              val flags=List.map(fn divisor=>if(bc div divisor)mod 10=1 then 1 else 0)[100,10,1]
              val size=List.foldl(op +)0 flags
              fun number [] _=[]|number(flag::rest)offset=
                (if flag=0 then 0 else count+offset+1)::number rest(offset+flag)
          in(count+size,values@number flags 0)end
   in List.foldl one(0,[])(A.range 1(nnode db))end
 fun degreeCount db= #1(degreesAndCount db)
 fun nodeDegrees db node=
   let val values= #2(degreesAndCount db)val index=(node-1)*3
   in[List.nth(values,index),List.nth(values,index+1),List.nth(values,index+2)]end
 fun diagonal db=
   let val count=degreeCount db
       val initial=A.makevec count(fn _=>0)
       fun contributions element=
         let val(nl,nr)=elementNodes db element
             val degrees=List.filter(fn n=>n<>0)(nodeDegrees db nl)@List.filter(fn n=>n<>0)(nodeDegrees db nr)
         in List.map(fn x=>(x,L.delay(fn()=>x-List.hd degrees+1)))degrees end
       val band=A.maxupdvec initial(List.concat(List.map contributions(A.range 1(nelem db))))
   in A.recursiveVec count(fn self=>fn i=>if i=1 then 1 else A.vecsub self(i-1)+A.vecsub band i)end
 fun beam db element=
   let val nodes=L.delay(fn()=>elementNodes db element)
       val left=L.delay(fn()=>nodeXY db(#1(L.force nodes)))
       val right=L.delay(fn()=>nodeXY db(#2(L.force nodes)))
       val ea=L.delay(fn()=> #1(material db(elementMaterial db element)))
       val dx=L.delay(fn()=>R.sub(#1(L.force right),#1(L.force left)))
       val dy=L.delay(fn()=>R.sub(#2(L.force right),#2(L.force left)))
       val length=L.delay(fn()=>R.sqrt(R.add(R.mul(L.force dx,L.force dx),R.mul(L.force dy,L.force dy))))
       val c=L.delay(fn()=>R.divide(L.force dx,L.force length))
       val sine=L.delay(fn()=>R.divide(L.force dy,L.force length))
       val a=L.delay(fn()=>R.divide(L.force ea,L.force length))
       val b1=L.delay(fn()=>R.mul(R.mul(L.force a,L.force c),L.force c))
       val b2=L.delay(fn()=>R.mul(R.mul(L.force a,L.force c),L.force sine))
       val b3=L.delay(fn()=>R.mul(R.mul(L.force a,L.force sine),L.force sine))
       fun one(i,j)=
         if(i=1 andalso j=1)orelse(i=4 andalso j=4)then L.force b1
         else if List.exists(fn p=>p=(i,j))[(2,1),(5,4),(1,2),(4,5)]then L.force b2
         else if(i=2 andalso j=2)orelse(i=5 andalso j=5)then L.force b3
         else if(i=1 andalso j=4)orelse(i=4 andalso j=1)then R.negative(L.force b1)
         else if List.exists(fn p=>p=(i,j))[(2,4),(5,1),(1,5),(4,2)]then R.negative(L.force b2)
         else if(i=2 andalso j=5)orelse(i=5 andalso j=2)then R.negative(L.force b3)
         else 0.0
   in A.makemat(6,6)one end
 fun stiffness db=
   let val initial=A.makevb(degreeCount db)(diagonal db)(fn _=>0.0)
       fun assemble(element,prior)=
         let val(nl,nr)=elementNodes db element
             val degrees=nodeDegrees db nl@nodeDegrees db nr
             val indexed=ListPair.zip(A.range 1 6,degrees)
             val active=List.filter(fn(_,degree)=>degree<>0)indexed
             fun at i=List.nth(active,i)
             val positions=List.concat(List.map(fn i=>List.map(fn j=>(i,j))(A.range 0 i))(A.range 0(List.length active-1)))
             val values=List.filter(fn(i,j)=> #2(at i)>0 andalso #2(at j)>0)positions
             fun entry(i,j)=((#2(at i),#2(at j)),L.delay(fn()=>A.matsub(beam db element)(#1(at i),#1(at j))))
         in prior@List.map entry values end
       val updates=List.foldl assemble[](A.range 1(nelem db))
   in A.incrvb R.add initial updates end
 fun loads db=
   let val initial=A.makevec(degreeCount db)(fn _=>0.0)
       fun assemble(point,prior)=
         let val(node,px,py,m)=pointLoad db point
             val pairs=ListPair.zip(nodeDegrees db node,[L.delay(fn()=>px),L.delay(fn()=>py),L.delay(fn()=>m)])
         in prior@List.filter(fn(degree,_)=>degree<>0)pairs end
   in A.incrvec R.add initial(List.foldl assemble[](A.range 1(nplds db)))end
 fun sum terms=List.foldl(fn(x,total)=>R.add(total,L.force x))0.0 terms
 fun decompose matrix=
   let val n=A.vbdim matrix val diagonal=A.vbdiag matrix
       fun entry self(i,j)=
         if i=j then
           R.sqrt(R.sub(A.vbsub matrix(i,i),sum(List.map(fn k=>L.delay(fn()=>R.mul(A.vbsub self(i,k),A.vbsub self(i,k))))
             (A.range(A.firstColumn matrix i)(i-1)))))
         else R.divide(R.sub(A.vbsub matrix(i,j),
           sum(List.map(fn k=>L.delay(fn()=>R.mul(A.vbsub self(i,k),A.vbsub self(j,k))))
             (A.range(Int.max(A.firstColumn matrix i,A.firstColumn matrix j))(j-1)))),
             A.vbsub self(j,j))
   in A.recursiveVB n diagonal entry end
 fun forward input matrix=
   A.recursiveVec(A.boundvec input)(fn self=>fn i=>
      R.divide(R.sub(A.vecsub input i,sum(List.map(fn j=>L.delay(fn()=>R.mul(A.vbsub matrix(i,j),A.vecsub self j)))
       (A.range(A.firstColumn matrix i)(i-1)))),A.vbsub matrix(i,i)))
 fun backward input matrix=
   let val n=A.boundvec input
   in A.recursiveVec n(fn self=>fn i=>
      R.divide(R.sub(A.vecsub input i,sum(List.map(fn j=>L.delay(fn()=>R.mul(A.vbsub matrix(j,i),A.vecsub self j)))
        (List.filter(fn j=>i>=A.firstColumn matrix j)(A.range(i+1)n)))),A.vbsub matrix(i,i)))end
 fun solve matrix input=let val factor=decompose matrix in backward(forward input factor)factor end
 fun displacement db=
   let val solution=L.delay(fn()=>solve(stiffness db)(loads db))
       val initial=A.makevec(3*nnode db)(fn _=>0.0)
       fun node node=
         let val indices=A.range(3*(node-1)+1)(3*node)
             val values=List.map(fn degree=>L.delay(fn()=>if degree=0 then 0.0 else A.vecsub(L.force solution)degree))(nodeDegrees db node)
         in ListPair.zip(indices,values)end
   in A.incrvec R.add initial(List.concat(List.map node(A.range 1(nnode db))))end
 fun nodeDisplacement uvw node=
   let val index=3*(node-1)+1
   in(A.vecsub uvw index,A.vecsub uvw(index+1),A.vecsub uvw(index+2))end
 fun forces db uvw=
   A.makevec(nelem db)(fn element=>
     let val(nl,nr)=elementNodes db element
         val(ea,_)=material db(elementMaterial db element)
         val(xl,yl)=nodeXY db nl val(xr,yr)=nodeXY db nr
         val dx=R.sub(xr,xl)val dy=R.sub(yr,yl)
         val length=R.sqrt(R.add(R.mul(dx,dx),R.mul(dy,dy)))
         val c=R.divide(dx,length)val sine=R.divide(dy,length)
         val(ul,vl,_)=nodeDisplacement uvw nl val(ur,vr,_)=nodeDisplacement uvw nr
     in R.mul(R.divide(ea,length),R.add(R.mul(R.sub(ur,ul),c),R.mul(R.sub(vr,vl),sine)))end)
end
