(* Translation of nofib real/symalg/RealM.hs. Infinite approximation trees
 * retain memoized branches in both policies; finite integer labels use D. *)
functor BenchSymalgRealFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure Z=IntInf
 datatype treeNode=Tree of Z.int D.t*treeNode L.delay*treeNode L.delay
 type tree=treeNode L.delay
 datatype realT=Real of tree
 fun power n=if n<0 then raise Domain else Z.pow(10,Z.toInt n)
 fun scale(x:Z.int,n:Z.int)=
   if n<=0 then Z.quot(x*power(1-n)+5,10)
   else Z.quot(Z.quot(x,power(n-1))+5,10)
 fun treeFrom(n:Z.int)=L.delay(fn()=>Tree(D.delay(fn()=>n),treeFrom(2*n-1),treeFrom(2*n-2)))
 val numberTree=treeFrom 0
 fun mapTree f tree=L.delay(fn()=>case L.force tree of Tree(x,left,right)=>
   Tree(D.delay(fn()=>f(D.force x)),mapTree f left,mapTree f right))
 fun lookupTree tree(n:Z.int)=
   let fun path 1 out=out
         |path n out=if Z.mod(n,2)=0 then path(Z.quot(n,2))(0::out)
                     else path(Z.quot(n,2))(1::out)
       fun follow [] tree=let val Tree(x,_,_)=L.force tree in D.force x end
         |follow(0::rest)tree=let val Tree(_,left,_)=L.force tree in follow rest left end
         |follow(_::rest)tree=let val Tree(_,_,right)=L.force tree in follow rest right end
   in follow(path(1-n)[])tree end
 fun eval(Real tree)(tol:Z.int)=
   if tol<=0 then lookupTree tree tol else scale(lookupTree tree 0,tol)
 fun msd tree(k:Z.int)=
   let val x=Z.abs(eval(Real tree)k)
   in if x>=1 andalso x<10 then k else if x=10 then k+1
      else if x>=1 then msd tree(k+1)else msd tree(k-1)end
 fun fromInteger x=Real(mapTree(fn n=>scale(x,n))numberTree)
 fun add x y=Real(mapTree(fn n=>Z.quot(eval x(n-1)+eval y(n-1)+5,10))numberTree)
 fun subtract x y=Real(mapTree(fn n=>Z.quot(eval x(n-1)-eval y(n-1)+5,10))numberTree)
 fun multiply(xr as Real x)(yr as Real y)=
   Real(mapTree(fn n=>
     let val m=if n>=0 then Z.quot(n+1,2)else Z.quot(n-1,2)
         val x0=eval xr m
         val y0=eval yr m
         fun auxiliary x y=
           let val y1=eval yr(n-msd x 0-2)
           in if y1=0 then 0
              else let val x1=eval xr(n-msd y 0-2)
                   in scale(x1*y1,4+msd x 0+msd y 0-n)end end
     in if x0=0 andalso y0=0 then 0 else if x0=0 then auxiliary y x
        else auxiliary x y end)numberTree)
 fun reciprocal(xr as Real x)=
   let val dx=L.delay(fn()=>msd x 0)
       fun f(m:Z.int)=
         if m>=0 then 0
         else if m= ~1 then Z.quot(10000,eval xr(L.force dx-2))
         else let val hm=Z.quot(m-1,2)
                  val fm=L.delay(fn()=>f hm)
              in scale(L.force fm*(scale(2,m+hm-2)-eval xr(L.force dx+m-1)*L.force fm),2-2*hm)end
   in Real(mapTree(fn n=>Z.quot(f(L.force dx+n)+5,10))numberTree)end
 fun divide x y=multiply x(reciprocal y)
 fun square(xr as Real x)=Real(mapTree(fn n=>
   let val m=if n>=0 then Z.quot(n+1,2)else Z.quot(n-1,2)
       val x0=eval xr m
   in if x0=0 then 0
      else let val x1=eval xr(n-msd x 0-2)
           in scale(x1*x1,4+2*msd x 0-n)end end)numberTree)
 fun sqrt(xr as Real x)=
   let val dx=L.delay(fn()=>msd x 0)
       val hdx=L.delay(fn()=>let val d=L.force dx in if d>=0 then Z.quot(d+1,2)else Z.quot(d,2)end)
       fun f(n:Z.int)(dx:Z.int)xr(m:Z.int)=
         if m>=0 then 0
         else if m= ~1 then
           let val hx=Z.quot(dx,2)
               val approximation=Real.toLargeInt IEEEReal.TO_NEAREST
                 (Math.sqrt(Real.fromLargeInt(eval xr(dx-10))))
           in scale(approximation,5-hx+n)end
         else let val hm=Z.quot(m-1,2)
                  val fm=L.delay(fn()=>f n dx xr hm)
              in Z.quot(L.force fm+Z.quot(eval xr(n+n),L.force fm),2)end
   in Real(mapTree(fn n=>if eval xr(2*n)=0 then 0
      else f n(2*L.force hdx+2)xr(~2*L.force hdx-2+n))numberTree)end
end
