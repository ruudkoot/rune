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
