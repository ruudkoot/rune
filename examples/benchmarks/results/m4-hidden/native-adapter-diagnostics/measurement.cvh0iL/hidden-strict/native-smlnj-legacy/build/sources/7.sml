functor BenchHiddenFn(D:BENCH_SUSPEND) =
struct
  structure N=BenchHiddenNumberFn(D)
  structure L=BenchLazy
  structure S=BenchStream
  type number=N.number
  datatype vector=Vec of number S.stream
  datatype edge=Edge of vector L.delay * vector L.delay
  datatype plate=Plate of int * edge S.stream
  type memo=bool L.delay array
  fun vector values=
    let val _=D.delay(fn()=>S.foldl(fn(value,())=>(D.force value;()))()values)
    in Vec values end
  fun vec values=vector(S.fromList values)
  fun constructed makers=
    vector(S.fromList(List.map(fn make=>D.delay(fn()=>D.force(make())))makers))
  val zeroVector=vec[N.zero,N.zero,N.zero]
  val zVector=vec[N.zero,N.zero,N.one]
  val minusZVector=vec[N.zero,N.zero,N.literal(~1.0)]
  fun coordinate(Vec values)i=S.nth values i
  fun x v=coordinate v 0
  fun y v=coordinate v 1
  fun z v=coordinate v 2
  fun add(Vec a,Vec b)=vector(S.zipWith N.add a b)
  fun subtract(Vec a,Vec b)=vector(S.zipWith N.sub a b)
  fun negative(Vec a)=vector(S.map N.negative a)
  fun multiply(a,b)=constructed[
    fn()=>N.sub(N.mul(y a,z b),N.mul(y b,z a)),
    fn()=>N.sub(N.mul(z a,x b),N.mul(z b,x a)),
    fn()=>N.sub(N.mul(x a,y b),N.mul(x b,y a))]
  fun scale value(Vec a)=vector(S.map(fn b=>N.mul(value,b))a)
  fun inner(Vec a,Vec b)=S.foldl(fn(value,total)=>N.add(total,value))N.zero(S.zipWith N.mul a b)
  fun length value=N.sqrt(inner(value,value))
  fun normalize value=scale(N.divide(N.one,length value))value
  fun equal(Vec a,Vec b)=
    let fun loop a b=case L.force a of S.Nil=>(case L.force b of S.Nil=>true|_=>false)
          |S.Cons(x,xs)=>(case L.force b of S.Nil=>false
            |S.Cons(y,ys)=>N.eq(L.force x,L.force y)andalso loop xs ys)
    in loop a b end
  fun parallel(a,b)=equal(multiply(a,b),zeroVector)
  fun project v=vec[x v,y v,N.zero]
  fun rotate view value=
    if equal(view,zeroVector)then value
    else let val r=normalize view
         in if equal(r,zVector)then value
            else if equal(r,minusZVector)then negative value
            else let val q=normalize(multiply(zVector,r))
                     val p=normalize(multiply(q,r))
                 in constructed[fn()=>inner(value,p),fn()=>inner(value,q),fn()=>inner(value,r)]end end
  fun edgeT support terminal=
    Edge(L.delay(fn()=>support),L.delay(fn()=>subtract(terminal,support)))
  fun support(Edge(s,_))=L.force s
  fun heading(Edge(_,h))=L.force h
  fun terminal e=add(support e,heading e)
  fun plateEdges(Plate(_,edges))=edges
  fun plateId(Plate(n,_))=n
  fun faceNormal p=normalize(multiply(heading(S.nth(plateEdges p)0),heading(S.nth(plateEdges p)1)))
  fun verticalEdge e=parallel(heading e,zVector)
  fun verticalPlate p=N.eq(z(faceNormal p),N.zero)
  fun rotateEdge view e=edgeT(rotate view(support e))(rotate view(terminal e))
  fun scaleVector factor base v=scale factor(subtract(v,base))
  fun scaleEdge factor base e=edgeT(scaleVector factor base(support e))(scaleVector factor base(terminal e))
  fun solve a b w=
    let val determinant=z(multiply(a,b))
    in if N.eq(determinant,N.zero)then S.empty()
       else S.singleton(N.divide(z(multiply(w,b)),determinant),N.divide(z(multiply(a,w)),determinant))end
  fun altitude p value=
    let val first=S.nth(plateEdges p)0 val second=S.nth(plateEdges p)1
        val s=support first val h1=heading first val h2=heading second
        val solutions=solve h1 h2(subtract(value,s))
    in case L.force solutions of S.Cons(solution,rest)=>
         (case L.force rest of S.Nil=>
           let val(a,b)=L.force solution
           in z(add(add(s,scale a h1),scale b h2))end|_=>raise Match)
       |_=>raise Match end
  fun onto value e=
    if verticalEdge e then equal(project value,project(support e))
    else let val v=project(subtract(value,support e))val w=project(heading e)
         in parallel(v,w)andalso N.le(N.zero,inner(v,w))andalso N.le(inner(v,w),inner(w,w))end
  fun any test values=case L.force values of S.Nil=>false
    |S.Cons(x,rest)=>test(L.force x)orelse any test rest
  fun all test values=case L.force values of S.Nil=>true
    |S.Cons(x,rest)=>test(L.force x)andalso all test rest
  fun into value p=
    if verticalPlate p then any(onto value)(plateEdges p)
    else let val zs=S.map(fn e=>z(multiply(subtract(value,support e),heading e)))(plateEdges p)
         in all(fn a=>N.ge(a,N.zero))zs orelse all(fn a=>N.le(a,N.zero))zs end
  fun cross a b=
    let val solutions=solve(negative(heading a))(heading b)(subtract(support a,support b))
        val valid=S.filter(fn(t,u)=>N.le(N.zero,t)andalso N.le(t,N.one)andalso N.le(N.zero,u)andalso N.le(u,N.one))solutions
    in S.map(fn(t,u)=>(add(support a,scale t(heading a)),add(support b,scale u(heading b))))valid end
  fun member value values=case L.force values of S.Nil=>false
    |S.Cons(x,rest)=>equal(value,L.force x)orelse member value rest
  fun nub values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
    |S.Cons(x,rest)=>S.Cons(x,nub(S.filter(fn y=>not(equal(L.force x,y)))rest)))
  fun overlap a b=nub(S.append(S.map support(S.filter(fn e=>into(support e)b)(plateEdges a)))
    (S.concatMap(fn e=>S.concatMap(fn k=>S.map #1(cross e k))(plateEdges b))(plateEdges a)))
  fun above a b=
    let val ab=L.delay(fn()=>L.force(overlap a b))
        val ba=L.delay(fn()=>L.force(overlap b a))
        val projected=L.delay(fn()=>L.force(nub(S.append(S.map project ab)(S.map project ba))))
    in if verticalPlate a then
         if verticalPlate b then any(fn p=>any(fn q=>N.gt(z p,z q))ba)ab
         else any(fn p=>N.gt(z p,altitude b p))ab
       else if verticalPlate b then any(fn q=>N.gt(altitude a q,z q))ba
       else any(fn p=>N.gt(altitude a p,altitude b p))projected end
  fun last values=case L.force values of S.Nil=>raise Empty
    |S.Cons(x,rest)=>(case L.force rest of S.Nil=>L.force x|_=>last rest)
  fun comp e p=L.delay(fn()=>
    let val inS=into(support e)p
        val inT=into(terminal e)p
    in if inS andalso inT then S.Nil
       else let val crosses=nub(S.concatMap(fn k=>S.map #1(cross e k))(plateEdges p))
            in case L.force crosses of S.Nil=>L.force(S.singleton e)
             |S.Cons(first,_)=>let val a=L.force first val b=last crosses
                val(v,w)=if N.le(length(subtract(support e,a)),length(subtract(support e,b)))then(a,b)else(b,a)
                in if inS andalso not inT then L.force(S.singleton(edgeT w(terminal e)))
                   else if not inS andalso inT then L.force(S.singleton(edgeT(support e)v))
                   else L.force(S.fromList[edgeT(support e)v,edgeT w(terminal e)])end end end)
  fun cmp p edges=S.concatMap(fn e=>comp e p)edges
  fun streamLength values=
    let fun loop n values=case L.force values of S.Nil=>n|S.Cons(_,rest)=>loop(n+1)rest
    in loop 0 values end
  fun memoIndex top bottom=(top-2)*(top-1)div 2+bottom-1
  fun makeMemo predicate object=
    let val count=streamLength object
        val cells=Array.array(count*(count-1)div 2,L.delay(fn()=>raise Fail "missing hidden memo entry"))
        fun outer values=case L.force values of S.Nil=>()
          |S.Cons(top,rest)=>
            let val a=L.force top
                fun inner values=case L.force values of S.Nil=>()
                  |S.Cons(bottom,tail)=>
                    let val b=L.force bottom val i=plateId a val j=plateId b
                    in if i>j then Array.update(cells,memoIndex i j,L.delay(fn()=>predicate a b))else();inner tail end
                val _=inner object
            in outer rest end
        val _=outer object
    in cells end
  fun lazyAbove(memory:memo)top bottom=
    let val n=plateId top val m=plateId bottom
    in if n>m then L.force(Array.sub(memory,memoIndex n m))
       else if n=m then false
       else if L.force(Array.sub(memory,memoIndex m n))then false else above top bottom end
  fun hide memory object bottom=
    let val tops=S.filter(fn top=>lazyAbove memory top bottom)object
        fun fold values=L.delay(fn()=>case L.force values of S.Nil=>L.force(plateEdges bottom)
          |S.Cons(top,rest)=>L.force(cmp(L.force top)(fold rest)))
    in fold tops end
  fun hideObject object=S.concatMap(fn bottom=>hide(makeMemo above object)object bottom)object
  fun rotateRight values=
    let val final=L.delay(fn()=>last values)
        fun withoutLast values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
          |S.Cons(x,rest)=>(case L.force rest of S.Nil=>S.Nil|_=>S.Cons(x,withoutLast rest)))
    in S.cons(final,withoutLast values)end
  fun makeObject faces=
    let fun loop index values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
          |S.Cons(face,rest)=>S.Cons(L.delay(fn()=>
             let val points=L.force face
             in Plate(index,S.zipWith(fn(a,b)=>edgeT a b)points(rotateRight points))end),loop(index+1)rest))
    in loop 1 faces end
  fun reduce operation values=
    let val first=S.head values
    in S.foldl(fn(value,total)=>operation(total,value))first(S.tail values)end
  fun extremes faces=
    let val points=S.concatMap(fn face=>face)faces
        val xs=S.map x points val ys=S.map y points
        val base=vec[reduce N.minimum xs,reduce N.minimum ys,N.zero]
        val factor=N.minimum(N.divide(N.literal 400.0,N.maximum(N.sub(reduce N.maximum xs,reduce N.minimum xs),N.one)),
          N.divide(N.literal 640.0,N.maximum(N.sub(reduce N.maximum ys,reduce N.minimum ys),N.one)))
    in(base,factor)end
  fun prepare view faces=
    let val rotated=S.map(fn face=>S.map(rotate view)face)faces
        val(base,factor)=extremes rotated
        val object=makeObject rotated
    in S.map(scaleEdge factor base)(hideObject object)end

  datatype command=Move of number*number|Line of number*number|Flush
  fun plot edges=
    let fun start values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
          |S.Cons(first,_)=>let val point=support(L.force first)
            in S.Cons(L.delay(fn()=>Move(x point,y point)),from point values)end)
        and from current values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
          |S.Cons(first,rest)=>let val edge=L.force first
             in if equal(support edge,current)then
                  let val point=terminal edge
                  in S.Cons(L.delay(fn()=>Line(x point,y point)),from point rest)end
                else S.Cons(L.delay(fn()=>Flush),start values)end)
    in start edges end
end
