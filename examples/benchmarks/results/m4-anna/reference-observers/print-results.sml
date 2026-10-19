
 fun justify width chars=F.append(copy(subtract width(length chars))(cell #" "))chars
 fun numberedLines values=
   let fun loop n values=F.defer(fn()=>case force values of F.Nil=>F.empty()
         |F.Cons(x,rest)=>textConcat[justify(int 4)(renderInteger n),text") ",x,text"\n",loop(add n(int 1))rest])
   in loop(int 1)values end
 fun minInteger a b=if less a b then a else b
 fun maxInteger a b=if less a b then b else a
 fun listMinimum values=foldLeft minInteger(head values)(tail values)
 fun listMaximum values=foldLeft maxInteger(head values)(tail values)
 fun liftPrintedDomain points=
   let val width=length(head points)
       val bottom=subtract(listMinimum(concat points))(int 1)
   in F.cons(copy width bottom,points)end
 fun crossPrintedDomain xs ys=flatMap(fn x=>map(fn y=>F.append x y)ys)xs
 fun crossPrintedDomains values=F.defer(fn()=>case force values of F.Nil=>singleton(singleton(int 0))
   |F.Cons(x,rest)=>if null rest then x else crossPrintedDomain x(crossPrintedDomains rest))
 (* Preserve source [[-1],[0]], product order, and repeated lifting. *)
 fun printedDomain domain=F.defer(fn()=>case force domain of
    Two=>F.cons(singleton(int ~1),singleton(singleton(int 0)))
   |Lift1 ds=>liftPrintedDomain(crossPrintedDomains(map printedDomain ds))
   |Lift2 ds=>liftPrintedDomain(liftPrintedDomain(crossPrintedDomains(map printedDomain ds)))|_=>raise Match)
 fun printAllPoints domain=
   let val points=printedDomain domain
       val minimum=listMinimum(concat points)
       fun character n=cell(Char.chr(small(add n(int 48))))
       val normalized=map(fn row=>map(fn n=>subtract n minimum)row)points
       val rows=map(map character)normalized
   in textConcat[text"{",interleave(text" ")rows,text"}"]end
 fun printedWidth domain:integer=D.delay(fn()=>case force domain of Two=>force(int 1)
   |Lift1 ds=>force(foldLeft add(int 0)(map printedWidth ds))
   |Lift2 ds=>force(foldLeft add(int 0)(map printedWidth ds))|_=>raise Match)
 fun printedLifts domain:integer=D.delay(fn()=>case force domain of Two=>force(int 2)
   |Lift1 ds=>force(add(int 1)(listMaximum(map printedLifts ds)))
   |Lift2 ds=>force(add(int 2)(listMaximum(map printedLifts ds)))|_=>raise Match)
 fun printedRoute domain route=F.defer(fn()=>case(force domain,force route)of
    (Two,Zero)=>singleton(int 0)|(Two,One)=>singleton(int 1)
   |(Lift1 _,Stop1)=>copy(printedWidth domain)(int 0)
   |(Lift1 ds,Up1 rs)=>map(add(int 1))(printedCrossRoutes ds rs)
   |(Lift2 _,Stop2)=>copy(printedWidth domain)(int 0)
   |(Lift2 _,Up2)=>copy(printedWidth domain)(int 1)
   |(Lift2 ds,UpUp2 rs)=>map(add(int 2))(printedCrossRoutes ds rs)|_=>raise Match)
 and printedCrossRoutes domains routes=
   let val unadjusted=zipExact printedRoute domains routes
       val factors=map printedLifts domains
       val maximum=listMaximum factors
       val normalized=map(subtract maximum)factors
       val fixed=zipExact(fn n=>fn route=>map(add n)route)normalized unadjusted
   in concat fixed end
 fun printRoute domain route=map(fn n=>cell(Char.chr(small(add n(int 48)))))(printedRoute domain route)
 fun printFunction mindless statics fname domain point=F.defer(fn()=>
   case(force domain,force point)of(Func(args,target),Rep rep)=>
     if isHigherOrderFunction domain orelse hasFlag statics NoFormat then
       textConcat[text"\nFunction ",renderQuoted fname,text" has input domains:\n",
          numberedLines(map(renderDomain 0)args),text"   and output domain\n      ",
          renderDomain 0 target,text"\n\nwith value:\n\n",renderRepresentation 0 rep,text"\n\n"]
     else
       let val params=sureLookup equalName(staticFreeVariables statics)"prPrintFunction"fname
           val prettyArgs=map printAllPoints args
           fun labelled params domains=F.defer(fn()=>case force domains of F.Nil=>F.empty()
             |F.Cons(domain,rest)=>case force params of F.Nil=>F.cons(domain,labelled params rest)
                |F.Cons(n,ns)=>F.cons(if null n then domain else
                     textConcat[domain,text" (free ",renderQuoted n,text")"],labelled ns rest))
           val numbered=numberedLines(labelled params prettyArgs)
           val outputs=reverse(insertionSort compareRoute(allRoutes target))
           fun row output=
             let val inverses=minimumInverse mindless domain(cell(Rep rep))output
                 val column=printRoute target output
                 fun lower value=let val MkFrel routes=force value
                    in interleave(text" ")(zipExact printRoute args routes)end
             in textConcat[copy(subtract(int 8)(length column))(cell #" "),column,text"   |  ",
                  interleave(text" and ")(map lower inverses),text"\n"]end
       in textConcat[text"\nFunction ",renderQuoted fname,text" has input domains:\n",numbered,
           text"   and output domain\n      ",printAllPoints target,
           text"\n\n   Output  |  Lower frontier\n   --------+----------------\n",flatMap row outputs,text"\n\n"]end
    |_=>
       if containsFunctions domain then
          textConcat[text"\nFunction ",renderQuoted fname,text" is a higher-order constant (yuck) in domain\n\n",
            renderDomain 0 domain,text"\n\nof value\n\n",renderRoute 0 point,text"\n\n"]
       else textConcat[text"\nFunction ",renderQuoted fname,text" is a constant point ",printRoute domain point,
          text" in domain \n    ",printAllPoints domain,text"\n\n"])
 fun printSizeRows used values=flatMap(fn value=>let val(size,domains)=force value
   in textConcat[justify(int 8)(renderInteger size),text" ",text(if used then" "else"*"),text" ",
       renderList(renderDomain 0)domains,text"\n"]end)values
 fun printAnalysisInformation statics mindless info=F.defer(fn()=>case force info of
    SAResult(name,domain,point)=>printFunction mindless statics name domain point
   |SASearch(mode,name,size,count)=>textConcat[text"Evaluated at size ",justify(int 7)(renderInteger size),
       text" using ",justify(int 4)(renderInteger count),text" evals ",text(case mode of Safe=>"safe"|Live=>"live"),
       text" ",renderQuoted name,text"\n"]
   |SASizes(name,used,unused)=>textConcat[text"\nDomains for ",renderQuoted name,text" are\n",
       printSizeRows true used,printSizeRows false unused,text"\n"]
   |SAHExpr(name,tree)=>textConcat[text"\nAbstract tree for ",renderQuoted name,text" is\n\n",renderAbstract 0 tree,text"\n\n"]
   |SAGiveUp names=>textConcat[text"Giving up on ",interleave(text" and ")(map renderQuoted names),text".\n"]
   |_=>raise Match)
 fun settingInformation poly mono low high scale mindless baraki=
   textConcat[text"\n================\n=== Settings ===\n================\n\nScaleup ratio = ",renderInteger scale,
     text"/10\nLower lattice size limit = ",renderInteger low,text"\nUpper lattice size limit = ",renderInteger high,
     if baraki then textConcat[text"\nPolymorphic generalisation limit = ",renderInteger poly]
       else text"\nNot using Gebreselassie Baraki's generalisation technique.",
     text(if mindless then"\nUsing inefficient inverses"else""),
     text"\n\n\n==================\n=== Strictness ===\n==================\n"]
