(* Sparse block solver by Brian D. Moe; Kamini Shenoi modifications.
   Haskell conversion: Ian R. McLelland and Cordelia V. Hall.
   Roger L. Wainwright input representation. Original headers retained. *)
functor BenchLinearFn(D:BENCH_SUSPEND) =
struct
  structure B=BenchLinearDenseFn(D)
  structure L=BenchLazy
  structure S=BenchStream
  type number=B.number
  type denseVector=B.vector
  type block=B.matrix
  datatype entry=E of int*int*block
  type matrix=entry S.stream S.stream
  type vector=denseVector S.stream
  fun row r m=B.delay(fn()=>if r>=0 andalso r<B.length m then S.nth m r
    else raise Fail "sparse row index")
  fun column c m=S.concatMap(fn row=>S.filter(fn E(_,j,_)=>j=c)row)m
  fun vecAt i v=B.delay(fn()=>if i>=0 andalso i<B.length v then S.nth v i
    else raise Fail "sparse vector index")
  fun zeroBlock r c m=B.delay(fn()=>
    let val E(_,_,br)=S.head(row r m)val E(_,_,bc)=S.head(column c m)
    in B.repeat(B.rows br)(B.repeat(B.columns bc)B.zero)end)
  fun at r c m=B.delay(fn()=>
    let val matching=S.map(fn E(_,_,block)=>block)(S.filter(fn E(_,j,_)=>j=c)(row r m))
    in if B.empty matching then zeroBlock r c m else S.head matching end)
  fun vadd a b=S.zipWith(fn(x,y)=>B.vadd x y)a b
  fun vsub a b=S.zipWith(fn(x,y)=>B.vsub x y)a b
  fun svmult s v=S.map(fn x=>B.smul s x)v
  fun dot a b=B.scalar(fn()=>B.value(B.fold1 B.add(S.zipWith(fn(x,y)=>B.dot x y)a b)))
  fun norm v=B.scalar(fn()=>B.value(B.fold1 B.add(S.map B.norm v)))
  fun mvmult rows v=B.delay(fn()=>
    if B.length rows<>B.length v then raise Fail "incompatible sparse operands"else
      S.map(fn entries=>B.delay(fn()=>B.fold1(fn(a,b)=>B.vadd a b)
        (S.map(fn E(_,c,block)=>B.matvec block(vecAt c v))entries)))rows)
  fun blocknums m=B.range 0(B.length m-1)
  fun diagBlocks m=
    let val diags=S.map(fn i=>S.filter(fn E(r,c,_)=>r=c)(row i m))(blocknums m)
    in B.delay(fn()=>if B.length diags=B.length m then B.concat diags
      else raise Fail "diagonal block count")end
  fun scale m vs=
    let val inverses=S.map(fn E(_,_,block)=>B.inverse block)(diagBlocks m)
        fun factor n=B.delay(fn()=>if n>=0 andalso n<B.length inverses then S.nth inverses n
          else raise Fail "diagonal inverse index")
        fun scaleEntry(E(r,c,block))=E(r,c,B.delay(fn()=>if r=c then B.identity(B.rows block)
          else B.mmult(factor r)block))
        val m'=S.map(fn i=>S.map scaleEntry(row i m))(blocknums m)
        val v'=S.map(fn r=>B.matvec(factor r)(vecAt r vs))(B.range 0(B.length vs-1))
    in(m',v')end
  fun blocksum values=B.delay(fn()=>B.fold1(fn(a,b)=>B.madd a b)values)
  fun vecsum values=B.delay(fn()=>B.fold1(fn(a,b)=>B.vadd a b)values)
  fun columnsBefore n entries=S.filter(fn E(_,c,_)=>c<n)entries
  fun listMult xs ys=B.delay(fn()=>case(L.force xs,L.force ys)of
      (S.Nil,S.Nil)=>S.empty()
    |(S.Nil,S.Cons(_,rest))=>if B.empty rest then S.empty()else raise Match
    |(S.Cons(_,rest),S.Nil)=>if B.empty rest then S.empty()else raise Match
    |(S.Cons(a,ar),S.Cons(b,br))=>if B.empty ar andalso B.empty br then
        S.singleton(B.mmult(L.force a)(L.force b))else raise Match)
  fun listSub xs ys=B.delay(fn()=>case(L.force xs,L.force ys)of
      (S.Nil,S.Nil)=>S.empty()
    |(S.Nil,S.Cons(y,rest))=>if B.empty rest then S.singleton(S.map B.vneg(L.force y))else raise Match
    |(S.Cons(x,rest),S.Nil)=>if B.empty rest then S.singleton(L.force x)else raise Match
    |(S.Cons(a,ar),S.Cons(b,br))=>if B.empty ar andalso B.empty br then
        S.singleton(B.msub(L.force a)(L.force b))else raise Match)
  fun sumBlocks values=B.delay(fn()=>
    let val all=B.concat values
    in if B.empty all then S.empty()else S.singleton(blocksum all)end)
  fun pseudofactor n mat=
    let val maxBlock=L.delay(fn()=>List.last(S.take(B.length mat)(blocknums mat)))
        val firstColumns=S.map(fn r=>let val values=row r mat
              in if B.empty values then L.force maxBlock
                 else let val E(_,c,_)=S.head values in c end end)(B.range n(B.length mat-1))
        fun firstColumn r=S.nth firstColumns(r-n)
        fun exists r c=if c>r then exists c r else c>=firstColumn r
        fun newRow self k=
          let fun biluEntry(E(r,c,old))=E(r,c,B.delay(fn()=>
                  if r<>c then old else
                    let val products=S.map(fn E(u,k,buk)=>
                          B.mmult(B.mmult buk(at k k self))(at k u self))
                          (columnsBefore r(row r self))
                        val new=if B.empty products then old else B.msub old(blocksum products)
                    in B.inverse new end))
              val bilu=B.delay(fn()=>if k>=n then S.empty()else S.map biluEntry(columnsBefore n(row k mat)))
              fun bcluEntry i j=
                let val upper=S.map(fn E(_,k,bik)=>
                      listMult(S.singleton bik)(S.singleton(at k j mat)))
                      (S.filter(fn E(_,k,_)=>k<i)(row i mat))
                    val lower=S.map(fn E(_,k,bik)=>
                      listMult(listMult(S.singleton bik)(S.singleton(at k k self)))(S.singleton(at k j self)))
                      (S.filter(fn E(_,k,_)=>k<j)(row i mat))
                    val result=B.delay(fn()=>if i<j then
                        listMult(S.singleton(at i i self))(listSub(S.singleton(at i j mat))(sumBlocks upper))
                      else listSub(S.singleton(at i j mat))(sumBlocks lower))
                    val block=B.delay(fn()=>if B.empty result then raise Fail "pseudofactor"
                      else if i=j then B.inverse(S.head result)else S.head result)
                in E(i,j,block)end
              val bclu=B.delay(fn()=>S.map(fn c=>bcluEntry k c)
                (S.filter(fn c=>exists k c)(if k<n then B.range n(L.force maxBlock)else blocknums mat)))
          in S.append bilu bclu end
    in S.fix(fn self=>L.force(S.map(newRow self)(blocknums mat)))end
  fun forward m rs=
    let val holder=ref(NONE:denseVector S.stream S.stream option)
        fun parts k=S.nth(valOf(!holder))k
        fun terms k=B.delay(fn()=>if B.empty(parts k)then vecAt k rs
          else B.vsub(vecAt k rs)(vecsum(parts k)))
        fun y k=B.matvec(at k k m)(terms k)
        val sumParts=S.map(fn k=>S.map(fn E(_,j,block)=>B.matvec block(B.delay(fn()=>y j)))
             (S.filter(fn E(i,j,_)=>j<i)(row k m)))(blocknums m)
        val _=holder:=SOME sumParts
    in S.map y(blocknums m)end
  fun backward m ys=
    let val psHolder=ref(NONE:vector option)
        val termsHolder=ref(NONE:denseVector S.stream S.stream option)
        fun p k=B.delay(fn()=>S.nth(valOf(!psHolder))k)
        fun terms k=S.nth(valOf(!termsHolder))k
        fun p' k=B.delay(fn()=>if B.empty(terms k)then vecAt k ys
          else B.vsub(vecAt k ys)(B.matvec(at k k m)(vecsum(terms k))))
        val ps=S.map p'(blocknums m)
        val termss=S.map(fn k=>S.map(fn E(_,j,block)=>B.matvec block(p j))
          (S.filter(fn E(i,j,_)=>j>i)(row k m)))(blocknums m)
        val _=psHolder:=SOME ps val _=termsHolder:=SOME termss
    in ps end
  fun precondition nwells a v=
    let val firstWell=B.length a-nwells
        val factor=pseudofactor firstWell a
    in backward factor(forward factor v)end
  val hardOff=B.block[
    [~1.0,~2.0,~3.0,~4.0],[~4.0,~1.0,~2.0,~3.0],
    [~3.0,~4.0,~1.0,~2.0],[~2.0,~3.0,~4.0,~1.0]]
  val hardDiag=B.block[
    [90.0,~2.0,~3.0,~4.0],[~4.0,90.0,~2.0,~3.0],
    [~3.0,~4.0,90.0,~2.0],[~2.0,~3.0,~4.0,40.0]]
  val hardOff=S.map(fn row=>S.map(fn x=>B.divide(x,B.number 90.0))row)hardOff
  val hardDiag=S.map(fn row=>S.map(fn x=>B.divide(x,B.number 90.0))row)hardDiag
  fun input n=
    let fun row r=
          let val modulus=(r mod n)-1
              val offset=if r<=n then 0 else (((r-1)div n)-1)*n
              val indices=if r=1 orelse r=n*n-n+1 then[1,2,n+1,n+2]
                else if r=n orelse r=n*n then[n-1,n,2*n-1,2*n]
                else if r mod n=1 then[1,2,n+1,n+2,2*n+1,2*n+2]
                else if r mod n=0 then[n-1,n,2*n-1,2*n,3*n-1,3*n]
                else if(r>1 andalso r<n)orelse(r>n*n-n+1 andalso r<n*n)
                  then[modulus,1+modulus,2+modulus,n+modulus,n+1+modulus,n+2+modulus]
                else[modulus,1+modulus,2+modulus,n+modulus,n+1+modulus,n+2+modulus,
                     2*n+modulus,2*n+1+modulus,2*n+2+modulus]
          in S.map(fn i=>E(r-1,i+offset-1,if r=i+offset then hardDiag else hardOff))(S.fromList indices)end
    in if n<=1 then raise Fail "linear hard-data system size too small"
       else S.map row(B.range 1(n*n))end
  fun solution n=S.map(fn _=>B.vec[1.0,1.0,1.0,1.0])(B.range 1(n*n))
  datatype state=State of vector*vector*vector*vector*int
  fun iterations (scaleFn:matrix->vector->matrix*vector)
      (precondFn:matrix->vector->vector) (a0:matrix) (b0:vector)=
    let val scaled=L.delay(fn()=>scaleFn a0 b0)
        val a=B.delay(fn()=> #1(L.force scaled))
        val b=B.delay(fn()=> #2(L.force scaled))
        val x0=vsub b0 b0 val r0=b
        val conditioner=L.delay(fn()=>precondFn a)
        val p0=B.delay(fn()=>(L.force conditioner)r0)
        val q0=mvmult a p0
        fun next(State(x,r,p,q,count))=
          let val qq=B.scalar(fn()=>B.value(dot q q))
              val rq=B.scalar(fn()=>B.value(dot r q))
              val alpha=B.divide(rq,qq)
              val x'=vadd x(svmult alpha p)
              val r'=vsub r(svmult alpha q)
              val p''=B.delay(fn()=>(L.force conditioner)r')
              val q''=mvmult a p''
              val qp=B.scalar(fn()=>B.value(dot q q''))
              val beta=B.divide(qp,qq)
              val p'=vsub p''(svmult beta p)
              val q'=vsub q''(svmult beta q)
          in State(x',r',p',q',count+1)end
    in S.iterate next(L.delay(fn()=>State(x0,r0,p0,q0,0)))end
  fun takeUntil predicate xs=L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
    |S.Cons(x,rest)=>if predicate(L.force x)then S.Cons(x,S.empty())
      else S.Cons(x,takeUntil predicate rest))
  fun stats n maxIterations=
    let val a=input n val soln=solution n val b=mvmult a soln
        fun converged(State(_,r,_,_,_))=B.value(B.sqrt(norm r))<B.value(B.number 0.0000004)
        val selected=takeUntil converged(B.take maxIterations(iterations scale(precondition 0)a b))
    in S.map(fn State(x,r,_,_,count)=>(count,norm(vsub x soln),norm r))selected end
end
