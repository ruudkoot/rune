(* Activity, spark and pool algorithms from the GRIP graph sources. *)
functor BenchGGGraphsFn(D:BENCH_SUSPEND) =
struct
 structure C=BenchGGCoreFn(D)
 structure G=BenchGGGraphicsFn(D)
 structure I=IntInf
 structure L=BenchLazy
 structure S=BenchStream
 open C
 datatype activity=GC|REDN|IDLE|FLUSH
 datatype spark=RESUMED|USED|CREATED|LOST
 datatype trace=Trace of number*number S.stream
 datatype mode=Activity of activity list|Sparks of spark list|Pool
 datatype format=Landscape|Portrait|Encapsulated of I.int*I.int
 fun list values=List.rev(S.foldl(fn(x,xs)=>x::xs)[]values)
 fun peKey(PE(name,no))=(String.implode name,value no)
 fun peLabel(PE(name,no))=String.implode name^"."^G.integer(value no)
 fun processorRows values=List.map(fn p=>(peKey p,peLabel p))(list values)
 fun actExtract GC(Act(_,_,_,g,_,_))=g
   |actExtract REDN(Act(_,_,r,_,_,_))=r
   |actExtract IDLE(Act(_,i,_,_,_,_))=i
   |actExtract FLUSH(Act(_,_,_,_,f,_))=f
 fun sparkExtract RESUMED(Sp(_,_,_,r,_))=r
   |sparkExtract USED(Sp(_,_,u,_,_))=u
   |sparkExtract CREATED(Sp(_,c,_,_,_))=c
   |sparkExtract LOST(Sp(_,_,_,_,l))=l
 fun actColor GC=I.fromInt 2|actColor REDN=0|actColor IDLE=8|actColor FLUSH=5
 fun actName GC="Garbage Collection"|actName REDN="Reduction"|actName IDLE="Idle"|actName FLUSH="Flush Read/Write"
 fun sparkColor RESUMED=I.fromInt 2|sparkColor USED=0|sparkColor CREATED=5|sparkColor LOST=8
 fun sparkName RESUMED="Resumed Sparks"|sparkName USED="Used Sparks"|sparkName CREATED="Sparks Created"|sparkName LOST="Sparks Lost"
 fun traceValues extract ordering entry=
   let fun loop []=S.empty()
         |loop(order as _::rest)=L.delay(fn()=>
           S.Cons(L.delay(fn()=>D.delay(fn()=>List.foldl(fn(kind,sum)=>I.+(sum,value(extract kind entry)))0 order)),
             loop rest))
   in loop ordering end
 fun outlines traces=L.delay(fn()=>case L.force traces of S.Nil=>raise Match
   |S.Cons(first,rest)=>
      let val Trace(n,values)=L.force first
          val points=S.map(fn y=>G.Pt(n,y))values
      in case L.force rest of S.Nil=>L.force(S.map S.singleton points)
         |_=>L.force(S.zipWith(fn(point,column)=>S.cons(L.delay(fn()=>point),column))points(outlines rest))end)
 fun curves colors columns=G.concat(list(S.zipWith(fn(color,points)=>G.plotCurve color points)(S.fromList colors)columns))
 fun actAggregate kind(i,r,g,f,t)=
   let val amount=case kind of IDLE=>i|REDN=>r|GC=>g|FLUSH=>f
       val percent=G.singleDiv(G.singleMul(G.fromSingle(value amount),100.0),G.fromSingle(value t))
   in G.printFloat percent^"%"end
 fun actStep ordering(i,r,g,f,t)(entry as Act(n,a,b,c,d,u))=
   (Trace(n,traceValues actExtract ordering entry),(add(a,i),add(b,r),add(c,g),add(d,f),add(t,u)))
 fun sparkStep ordering((c,u,r,l),maximum,width)(entry as Sp(n,a,b,d,e))=
   let val values=traceValues sparkExtract ordering entry
       val top=S.head values
   in(Trace(n,values),((add(a,c),add(b,u),add(d,r),add(e,l)),C.maximum(maximum,top),n))end
 fun poolStep((created,used,resumed),previous,maximum,width)(Sp(n,c,u,r,l))=
   let val top=add(previous,c)
       val usedLevel=D.delay(fn()=>I.-(value top,value l))
       val remaining=D.delay(fn()=>I.-(I.-(value top,value u),value l))
   in(Trace(n,S.fromList[top,usedLevel,remaining]),
      ((add(created,c),add(used,u),add(resumed,r)),remaining,C.maximum(maximum,top),n))end
 fun poolOutlines traces=
   let fun loop traces=L.delay(fn()=>case L.force traces of S.Nil=>(S.empty(),S.empty())
         |S.Cons(first,rest)=>
            let val Trace(n,values)=L.force first
                val p=S.nth values 0 val u=S.nth values 1 val l=S.nth values 2
                val t=D.delay(fn()=>I.*(value n,2))
                val next=D.delay(fn()=>I.+(value t,1))
                val tail=loop rest
            in(S.append(S.fromList[G.Pt(t,p),G.Pt(t,l),G.Pt(next,l)])
                 (L.delay(fn()=>L.force(#1(L.force tail)))),
               S.append(S.fromList[G.Pt(t,u),G.Pt(next,l)])
                 (L.delay(fn()=>L.force(#2(L.force tail)))))end)
   in loop traces end
 fun graph selected mode input=G.delay(fn()=>
   let val parameters=L.delay(fn()=>L.force(C.parameters(C.parseFile input)))
       val processors=L.delay(fn()=> #1(L.force parameters))
       val ticks=D.delay(fn()=>value(#2(L.force parameters)))
       val ordered=L.delay(fn()=>L.force(#3(L.force parameters)))
       val pes=L.delay(fn()=>processorRows(L.force processors))
       val selectedKeys=List.map peKey selected
       fun init title x y ylabel legend=G.delay(fn()=>
         G.initGraph title pes selectedKeys x y"Time (ms)"ylabel legend)
       val topX=D.delay(fn()=>I.*(value ticks,100))
   in (case mode of
     Activity ordering=>
       let val order=List.rev ordering
           val active=L.delay(fn()=>if List.null selected then I.fromInt(List.length(L.force pes)-1)
             else I.fromInt(List.length selected))
           val maxTicks=D.delay(fn()=>I.*(L.force active,value ticks))
           val data=S.map(scaleAct ticks)(getActs selected ordered)
           val gathered=gatherAct(Act(zero,zero,zero,zero,zero,zero))data
           val accumulated=C.accumulate(actStep order)(zero,zero,zero,zero,zero)gathered
           val traces=L.delay(fn()=>L.force(#1(L.force accumulated)))
           val totals=L.delay(fn()=>L.force(#2(L.force accumulated)))
           val legend=L.delay(fn()=>List.map(fn kind=>(actColor kind,actName kind,L.delay(fn()=>actAggregate kind(L.force totals))))ordering)
       in G.concat[init"Processor Activity Graph"topX(number 100)"% Activity"legend,
         G.delay(fn()=>G.scale(G.fromInt G.dimX/100.0)(G.fromInt G.dimY/G.fromInt(value maxTicks))),
         G.delay(fn()=>curves(List.map actColor order)(outlines traces))]end
    |Sparks ordering=>
       let val order=List.rev ordering
           val gathered=gatherSpark true(Sp(zero,zero,zero,zero,zero))(getSparks selected ordered)
           val accumulated=C.accumulate(sparkStep order)((zero,zero,zero,zero),zero,zero)gathered
           val traces=L.delay(fn()=>L.force(#1(L.force accumulated)))
           val state=L.delay(fn()=>L.force(#2(L.force accumulated)))
           val height=D.delay(fn()=>G.axisScale(value(#2(L.force state))))
           fun aggregate kind=
             let val((c,u,r,l),_,_)=L.force state
             in G.integer(value(case kind of CREATED=>c|USED=>u|RESUMED=>r|LOST=>l))end
           val legend=L.delay(fn()=>List.map(fn kind=>(sparkColor kind,sparkName kind,L.delay(fn()=>aggregate kind)))ordering)
       in G.concat[init"Spark Activity Graph"topX height"Sparks"legend,
         G.delay(fn()=>G.scale(G.fromInt G.dimX/100.0)(G.fromInt G.dimY/G.fromInt(value height))),
         G.delay(fn()=>curves(List.map sparkColor order)(outlines traces))]end
    |Pool=>
       let val gathered=gatherSpark false(Sp(zero,zero,zero,zero,zero))(getSparks selected ordered)
           val accumulated=C.accumulate poolStep((zero,zero,zero),zero,zero,zero)gathered
           val traces=L.delay(fn()=>L.force(#1(L.force accumulated)))
           val state=L.delay(fn()=>L.force(#2(L.force accumulated)))
           val height=D.delay(fn()=>G.axisScale(value(#3(L.force state))))
           val width=D.delay(fn()=>value(#4(L.force state)))
           val finished=S.append traces(S.singleton(Trace(width,S.fromList[zero,zero,zero])))
           val outlined=L.delay(fn()=>L.force(poolOutlines finished))
           val sparkPoints=L.delay(fn()=>L.force(#1(L.force outlined)))
           val usedPoints=L.delay(fn()=>L.force(#2(L.force outlined)))
       in G.concat[init"Spark Pool Profile Graph"topX height"Sparks"
           (L.delay(fn()=>[(5,"Spark Residency",L.delay(fn()=>"")),(0,"Sparks Used",L.delay(fn()=>""))])),
         G.delay(fn()=>G.scale(G.fromInt G.dimX/200.0)(G.fromInt G.dimY/G.fromInt(value height))),
         G.plotCurve 0 usedPoints,G.plotCurve 5 sparkPoints]end)end)
 fun run mode format selected input=
   let val body=graph selected mode input
   in case format of Landscape=>G.landscape body|Portrait=>G.portrait body
     |Encapsulated(dx,dy)=>G.encapsulated(dx,dy)body end
end
