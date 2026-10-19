(* The pinned BSPT Euclid and EuclidGMS definitions, with memoized coordinates,
   segment endpoints and region face lists. *)
functor BenchBSPTGeometryFn(D:BENCH_SUSPEND) =
struct
  structure R=BenchBSPTRationalFn(D)
  structure L=BenchLazy
  structure S=BenchStream
  datatype pointNode=Pt of R.rational*R.rational
  type point=pointNode L.delay
  datatype lineNode=Ln of R.rational*R.rational*R.rational
  type line=lineNode L.delay
  datatype faceNode=Fc of (point*point)L.delay*line
  type face=faceNode L.delay
  type faces=face S.stream
  datatype halfspace=Fore|Coin|Rear
  datatype location=Coincident|Intersects|ToTheRear|ToTheFore
  datatype region=Rg of faces
  fun point(x,y)=L.delay(fn()=>Pt(x,y))
  fun integerPoint(x,y)=point(R.number x,R.number y)
  fun line(a,b,c)=L.delay(fn()=>Ln(a,b,c))
  fun face endpoints equation=L.delay(fn()=>Fc(endpoints,equation))
  fun getSegment f=let val Fc(segment,_)=L.force f in segment end
  fun getLine f=let val Fc(_,equation)=L.force f in equation end
  fun getRegion(Rg faces)=faces
  fun newRegion(Rg faces)f=Rg(S.cons(L.delay(fn()=>f),faces))
  fun empty xs=case L.force xs of S.Nil=>true|_=>false
  fun length xs=let fun run n xs=case L.force xs of S.Nil=>n|S.Cons(_,rest)=>run(n+1)rest in run 0 xs end
  fun delayed f=L.delay(fn()=>L.force(f()))
  fun eqPoint a b=
    let val Pt(x,y)=L.force a val Pt(u,v)=L.force b in R.equal x u andalso R.equal y v end
  fun eqLine a b=
    let val Ln(x,y,z)=L.force a val Ln(u,v,w)=L.force b
    in R.equal x u andalso R.equal y v andalso R.equal z w end
  fun eqFace a b=
    let val Fc(x,l)=L.force a val Fc(y,m)=L.force b
        val(p,q)=L.force x val(r,s)=L.force y
    in eqPoint p r andalso eqPoint q s andalso eqLine l m end
  fun equation equation p=L.delay(fn()=>
    let val Ln(a,b,c)=L.force equation val Pt(x,y)=L.force p
    in L.force(R.add(R.add(R.mul a x)(R.mul b y))c)end)
  fun space equation point=
    let val value=equationValue equation point
    in if R.isZero value then Coin else if R.positive value then Fore else Rear end
  and equationValue eq pt=equation eq pt
  fun convert first second=L.delay(fn()=>
    let val Pt(x1,y1)=L.force first val Pt(x2,y2)=L.force second
        val dx=R.sub x2 x1 val dy=R.sub y2 y1
        val ratio=L.delay(fn()=>R.ratio dx dy)
        val diffx=delayed(fn()=> #1(L.force ratio))
        val diffy=delayed(fn()=> #2(L.force ratio))
    in Ln(diffy,R.negate diffx,R.sub(R.mul diffx y1)(R.mul diffy x1))end)
  fun invert equation=L.delay(fn()=>
    let val Ln(a,b,c)=L.force equation in Ln(R.negate a,R.negate b,R.negate c)end)
  fun mkFace(first,second)=face(L.delay(fn()=>(first,second)))(convert first second)
  fun solveAux first second=L.delay(fn()=>
    let val Ln(a,b,c)=L.force first val Ln(d,e,f)=L.force second
    in if R.equal d R.zero then
         let val y=R.divide f e val x=R.divide(R.sub c(R.mul b y))a in Pt(x,y)end
       else let val g=R.divide d a
            in L.force(solveAux first(line(R.zero,R.sub e(R.mul b g),R.sub f(R.mul c g))))end end)
  fun solve first second=L.delay(fn()=>
    let val Ln(a,b,c)=L.force first val Ln(d,e,f)=L.force second
    in if R.isZero(R.sub(R.mul a e)(R.mul b d))then L.force(integerPoint(0,0))
       else if not(R.isZero a)then L.force(solveAux(line(a,b,R.negate c))(line(d,e,R.negate f)))
       else L.force(solveAux(line(d,e,R.negate f))(line(a,b,R.negate c)))end)
  fun minus first second=L.delay(fn()=>
    let val Pt(x,y)=L.force first val Pt(u,v)=L.force second in Pt(R.sub u x,R.sub v y)end)
  fun triangleArea points=L.delay(fn()=>
    case S.take 4 points of[first,second,third]=>
      let val Pt(x1,y1)=L.force(minus first second)
          val Pt(x2,y2)=L.force(minus first third)
      in L.force(R.abs(R.mul R.half(R.sub(R.mul x1 y2)(R.mul y1 x2))))end
    |_=>raise Match)
  fun mkPolygon points=L.delay(fn()=>case L.force points of S.Nil=>S.Nil|S.Cons(first,rest)=>
    L.force(S.zipWith(fn(a,b)=>mkFace(a,b))points(S.append rest(S.singleton(L.force first)))))
  fun location equation segment=
    let val(first,second)=L.force segment
    in case(space equation first,space equation second)of
       (Coin,Coin)=>Coincident|(Fore,Rear)=>Intersects|(Rear,Fore)=>Intersects
      |(Rear,_)=>ToTheRear|(_,Rear)=>ToTheRear|_=>ToTheFore end
  fun toBack point equation=space equation point<>Fore
  fun bisect f second=
    let val first=getLine f
        val endpoints=getSegment f
        val intersection=solve first second
        val face1=face(L.delay(fn()=>(#1(L.force endpoints),intersection)))first
        val face2=face(L.delay(fn()=>(intersection,#2(L.force endpoints))))first
    in if toBack(#1(L.force endpoints))second then(face1,face2)else(face2,face1)end
  fun flip f=L.delay(fn()=>
    let val Fc(endpoints,equation)=L.force f
    in Fc(L.delay(fn()=>let val(a,b)=L.force endpoints in(b,a)end),invert equation)end)
  fun inRegion(Rg faces) point=
    let fun all values=case L.force values of S.Nil=>true|S.Cons(f,rest)=>
          toBack point(getLine(L.force f))andalso all rest
    in all faces end
  fun makeSet values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
    |S.Cons(first,rest)=>S.Cons(first,makeSet(S.filter(fn p=>not(eqPoint(L.force first)p))rest)))
  fun section region equation=L.delay(fn()=>
    let val points=S.filter(inRegion region)(S.map(fn f=>solve equation(getLine f))(getRegion region))
        fun select points=case S.take 3 points of[a,b]=>(a,b)|_=>select(makeSet points)
    in select points end)
  fun mkPart region equation=face(section region equation)equation
  fun vertices region=
    let val segments=S.map getSegment(getRegion region)
        val first=S.map(fn segment=> #1(L.force segment))segments
        val second=S.map(fn segment=> #2(L.force segment))segments
    in S.filter(inRegion region)(S.append first second)end
  val renderBorder=Rg(mkPolygon(S.fromList[
     integerPoint(120,0),integerPoint(900,0),integerPoint(900,510),integerPoint(120,510)]))
end
