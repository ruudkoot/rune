(* BSPT construction, classification and memoized region areas.
   Libfuns.par is the upstream sequential identity; Prelude.seq forces left. *)
functor BenchBSPTTreeFn(D:BENCH_SUSPEND) =
struct
  structure G=BenchBSPTGeometryFn(D)
  structure R=G.R
  structure L=BenchLazy
  structure S=BenchStream
  datatype status=In|Out|On
  datatype treeNode=Cell of status*G.region*R.rational
    |BSP of G.face*(G.faces*G.region)*treeNode L.delay*treeNode L.delay
  type tree=treeNode L.delay
  fun partPoints equation points=
    let val result=L.delay(fn()=>case L.force points of S.Nil=>(S.empty(),S.empty())
          |S.Cons(point,rest)=>
            let val(left,right)=partPoints equation rest
            in if G.toBack(L.force point)equation then(S.cons(point,left),right)
               else(left,S.cons(point,right))end)
    in(G.delayed(fn()=> #1(L.force result)),G.delayed(fn()=> #2(L.force result)))end
  fun triangles points=L.delay(fn()=>case S.take 4 points of
      [_,_]=>S.Nil
    |[a,b,c]=>L.force(S.singleton(S.fromList[a,b,c]))
    |a::b::rest=>
      let val tail=S.tail(S.tail points)
          val(left,right)=partPoints(G.convert a b)tail
      in L.force(if not(G.empty left)andalso not(G.empty right)then
           S.append(triangles(S.cons(L.delay(fn()=>a),S.cons(L.delay(fn()=>b),left))))
             (triangles(S.cons(L.delay(fn()=>a),S.cons(L.delay(fn()=>b),right))))
         else triangles(S.cons(L.delay(fn()=>a),S.append tail(S.singleton b))))end
    |_=>raise Match)
  fun areaRegion region=G.delayed(fn()=>
    S.foldl(fn(triangle,total)=>R.add total(G.triangleArea triangle))R.zero(triangles(G.vertices region)))
  fun mkCell status region=L.delay(fn()=>Cell(status,region,areaRegion region))
  fun partFaces equation faces=
    let val result=L.delay(fn()=>case L.force faces of S.Nil=>(S.empty(),S.empty(),S.empty())
          |S.Cons(f,rest)=>
            let val(rear,coin,fore)=partFaces equation rest
                val face=L.force f
                val halves=L.delay(fn()=>G.bisect face equation)
                fun leftHalf()= #1(L.force halves)
                fun rightHalf()= #2(L.force halves)
            in case G.location equation(G.getSegment face)of
                 G.Coincident=>(rear,S.cons(f,coin),fore)
                |G.Intersects=>(S.cons(L.delay leftHalf,rear),coin,S.cons(L.delay rightHalf,fore))
                |G.ToTheRear=>(S.cons(f,rear),coin,fore)
                |G.ToTheFore=>(rear,coin,S.cons(f,fore))end)
    in(G.delayed(fn()=> #1(L.force result)),G.delayed(fn()=> #2(L.force result)),
       G.delayed(fn()=> #3(L.force result)))end
  fun buildAux status region faces=L.delay(fn()=>case L.force faces of S.Nil=>L.force(mkCell status region)
    |_=>let val equation=G.getLine(S.head faces)
            val(rear,coin,fore)=partFaces equation faces
            val partition=G.mkPart region equation
            val left=buildAux In(G.newRegion region partition)rear
            val right=buildAux Out(G.newRegion region(G.flip partition))fore
            val _=L.force left
        in BSP(partition,(coin,region),left,right)end)
  fun build faces=buildAux Out G.renderBorder faces
  fun bspPrime partition(info as(_,region))left right=L.delay(fn()=>
    case L.force left of Cell(x,_,a)=>
      (case L.force right of Cell(y,_,b)=>
         if x=y then Cell(x,region,R.add a b)else BSP(partition,info,left,right)
       |_=>BSP(partition,info,left,right))
    |_=>BSP(partition,info,left,right))
  fun segments cellop tree face=L.delay(fn()=>case L.force tree of
      Cell(status,_,_)=>L.force(cellop status face)
    |BSP(partition,_,left,right)=>
      let val equation=G.getLine partition
          val halves=L.delay(fn()=>G.bisect face equation)
      in L.force(case G.location equation(G.getSegment face)of
           G.Coincident=>cellop In face
          |G.Intersects=>S.append(segments cellop left(G.delayed(fn()=> #1(L.force halves))))
               (segments cellop right(G.delayed(fn()=> #2(L.force halves))))
          |G.ToTheRear=>segments cellop left face
          |G.ToTheFore=>segments cellop right face)end)
  fun classifyFace tree faces=S.concatMap(fn face=>segments(fn status=>fn f=>S.singleton(f,status))tree face)faces
  fun rubout tree(face,status)=segments(fn other=>fn f=>if status=other then S.empty()else S.singleton f)tree face
  fun updateFaces left right faces=S.concatMap(rubout right)(classifyFace left faces)
  fun simplify partition region left right=L.delay(fn()=>case L.force left of Cell _=>
       (case L.force right of BSP(part,(faces,_),l,r)=>BSP(G.mkPart region(G.getLine part),(faces,region),l,r)
        |_=>L.force(bspPrime partition(S.empty(),region)left right))
    |BSP(part,(faces,_),l,r)=>
       (case L.force right of Cell _=>BSP(G.mkPart region(G.getLine part),(faces,region),l,r)
        |_=>L.force(bspPrime partition(S.empty(),region)left right)))
  fun bspDouble partition(faces,region)left right=L.delay(fn()=>
    let val updated=updateFaces left right faces
    in if G.empty updated then L.force(simplify partition region left right)
       else BSP(partition,(updated,region),left,right)end)
  fun inside In f=S.singleton f|inside Out _=S.empty()|inside On _=raise Match
  fun scanLine tree face=segments inside tree face
  fun fold cellop nodeop tree=L.delay(fn()=>case L.force tree of Cell(status,region,area)=>cellop status region area
    |BSP(partition,info,left,right)=>nodeop partition info(fold cellop nodeop left)(fold cellop nodeop right))
  fun countLeaves tree=L.force(fold(fn _=>fn _=>fn _=>1)
      (fn _=>fn _=>fn l=>fn r=>L.force l+L.force r)tree)
  fun sumRegion In _ a=a|sumRegion _ _ _=R.zero
  fun area tree=G.delayed(fn()=>L.force(fold sumRegion
      (fn _=>fn _=>fn l=>fn r=>R.add(G.delayed(fn()=>L.force l))(G.delayed(fn()=>L.force r)))tree))
  fun classify point tree=L.force(fold(fn status=>fn _=>fn _=>status)
      (fn partition=>fn _=>fn left=>fn right=>case G.space(G.getLine partition)point of
          G.Fore=>L.force right|G.Rear=>L.force left|G.Coin=>
            let val x=L.force left val y=L.force right in if x=y then x else On end)tree)
  fun complement tree=L.delay(fn()=>case L.force tree of
      Cell(In,region,area)=>Cell(Out,region,area)
    |Cell(Out,region,area)=>Cell(In,region,area)
    |Cell(On,_,_)=>raise Match
    |BSP(partition,info,left,right)=>BSP(partition,info,complement left,complement right))
  fun partTree partition tree=
    let val split=L.delay(fn()=>case L.force tree of
        Cell(status,region,_) =>
          (mkCell status(G.newRegion region partition),mkCell status(G.newRegion region(G.flip partition)))
      |BSP(old,(faces,region),rear,fore)=>
        let val p=G.getLine partition val t=G.getLine old
            fun both()=
              let val oldHalves=L.delay(fn()=>G.bisect old p)
                  val newHalves=L.delay(fn()=>G.bisect partition t)
                  val pLeft=G.delayed(fn()=> #1(L.force newHalves))
                  val pRight=G.delayed(fn()=> #2(L.force newHalves))
                  val rearSplit=L.delay(fn()=>partTree pLeft rear)
                  val foreSplit=L.delay(fn()=>partTree pRight fore)
                  val(rearFaces,_,foreFaces)=partFaces p faces
                  fun project index pair=L.delay(fn()=>L.force(index(L.force pair)))
              in(bspPrime(G.delayed(fn()=> #1(L.force oldHalves)))(rearFaces,G.newRegion region pLeft)
                    (project #1 rearSplit)(project #1 foreSplit),
                 bspPrime(G.delayed(fn()=> #2(L.force oldHalves)))(foreFaces,G.newRegion region pRight)
                    (project #2 rearSplit)(project #2 foreSplit))end
            fun splitRear()=partTree partition rear
            fun splitFore()=partTree partition fore
        in case G.location p(G.getSegment old)of
           G.Coincident=>if G.eqLine p t then(rear,fore)else(fore,rear)
          |G.ToTheFore=>
             (case G.location t(G.getSegment partition)of
                G.ToTheFore=>
                  let val(a,b)=splitFore()
                  in(a,bspPrime old(faces,G.newRegion region(G.flip partition))rear b)end
               |G.ToTheRear=>
                  let val(a,b)=splitRear()
                  in(a,bspPrime old(faces,G.newRegion region(G.flip partition))b fore)end
               |_=>both())
          |G.ToTheRear=>
             (case G.location t(G.getSegment partition)of
                G.ToTheFore=>
                  let val(a,b)=splitFore()
                  in(bspPrime old(faces,G.newRegion region partition)rear a,b)end
               |G.ToTheRear=>
                  let val(a,b)=splitRear()
                  in(bspPrime old(faces,G.newRegion region partition)a fore,b)end
               |_=>both())
          |G.Intersects=>both()end)
    in(L.delay(fn()=>L.force(#1(L.force split))),L.delay(fn()=>L.force(#2(L.force split))))end
  fun merge operation first second=L.delay(fn()=>case L.force first of
      Cell _=>L.force(operation first second)
    |BSP(partition,info,left,right)=>
       (case L.force second of Cell _=>L.force(operation first second)
        |BSP _=>
          let val(rear,fore)=partTree partition second
          in L.force(bspDouble partition info(merge operation left rear)(merge operation right fore))end))
  fun unionRule first second=case L.force first of
      Cell(In,_,_)=>first|Cell(Out,_,_)=>second|Cell(On,_,_)=>raise Match
    |BSP _=>(case L.force second of Cell(In,_,_)=>second|Cell(Out,_,_)=>first|_=>raise Match)
  fun intersectionRule first second=case L.force first of
      Cell(In,_,_)=>second|Cell(Out,_,_)=>first|Cell(On,_,_)=>raise Match
    |BSP _=>(case L.force second of Cell(In,_,_)=>first|Cell(Out,_,_)=>second|_=>raise Match)
  fun union first second=merge unionRule first second
  fun intersection first second=merge intersectionRule first second
  fun subtract first second=intersection first(complement second)
end
