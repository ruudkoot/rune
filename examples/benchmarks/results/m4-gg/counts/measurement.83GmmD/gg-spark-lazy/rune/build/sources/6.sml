(* GRIP runtime-graph analysis, attributed to Iain Checkland by gg.1.
   The supplied statistics are processed sequentially. *)
functor BenchGGCoreFn(D:BENCH_SUSPEND) =
struct
 structure I=IntInf
 structure L=BenchLazy
 structure S=BenchStream
 type number=I.int D.t
 datatype pe=PE of char list*number
 datatype activities=Act of number*number*number*number*number*number
 datatype sparks=Sp of number*number*number*number*number
 datatype line=Ln of pe L.delay*activities L.delay*sparks L.delay|PEs of pe L.delay|Null
 fun value(n:number)=D.force n
 fun number(n:I.int)=D.delay(fn()=>n)
 val zero=number 0
 fun add(a,b)=D.delay(fn()=>I.+(value a,value b))
 fun maximum(a,b)=D.delay(fn()=>I.max(value a,value b))
 fun span test input=case input of []=>([],[])
   |c::rest=>if test c then let val(a,b)=span test rest in(c::a,b)end else([],input)
 fun white input=case input of c::rest=>if Char.isSpace c then white rest else input|_=>input
 fun lines []=[]
   |lines input=let val(row,rest)=span(fn c=>c<> #"\n")input
     in row::(case rest of []=>[]|_::tail=>lines tail)end
 fun integer input=
   let val(digits,rest)=span Char.isDigit(white input)
       val n=D.delay(fn()=>
         let fun sum _ []=I.fromInt 0
               |sum power(c::tail)=I.+(I.*(I.fromInt(Char.ord c-Char.ord #"0"),I.pow(10,power)),sum(power-1)tail)
         in sum(List.length digits-1)digits end)
   in(n,rest)end
 fun processor input=
   let val(name,rest)=span(fn c=>c<> #".")(white input)
       val(n,tail)=case rest of #"."::rest=>integer rest|_=>raise Fail "GRIP processor is missing dot"
   in(PE(name,n),tail)end
 fun colon(#":"::rest)=rest
   |colon _=raise Fail "GRIP field is missing colon"
 fun line text=case white text of
   #"B"::rest=>
     let val parsedPE=L.delay(fn()=>processor rest)
         val parsedBucket=L.delay(fn()=>integer(colon(#2(L.force parsedPE))))
         val fields=L.delay(fn()=>
           let val(a,r1)=integer(colon(#2(L.force parsedBucket)))
               val(b,r2)=integer r1 val(c,r3)=integer r2
               val(d,r4)=integer r3 val(e,r5)=integer r4
               val(_,r6)=span(fn c=>c<> #" ")(white r5)
               val(f,r7)=integer r6 val(g,r8)=integer r7
               val(h,r9)=integer r8 val(i,r10)=integer r9 val(j,_)=integer r10
           in(a,b,c,d,e,f,g,h,i,j)end)
         val p=L.delay(fn()=> #1(L.force parsedPE))
         val act=L.delay(fn()=>
           let val(a,b,c,d,e,_,_,_,_,j)=L.force fields
               val total=List.foldl(fn(x,total)=>add(total,x))a[b,c,d,e,j]
           in Act(#1(L.force parsedBucket),a,b,c,add(d,e),total)end)
         val spark=L.delay(fn()=>
           let val(_,_,_,_,_,a,b,c,d,_)=L.force fields
           in Sp(#1(L.force parsedBucket),a,b,c,d)end)
         val _=D.delay(fn()=>(L.force p;L.force act;L.force spark;()))
     in Ln(p,act,spark)end
  | #"P":: #"S"::rest=>
      let val(_,afterR)=span(fn c=>c<> #"r")rest
          val p=L.delay(fn()=> #1(processor(case afterR of _::tail=>tail|_=>raise Fail "GRIP processor header is missing for")))
          val _=D.delay(fn()=>(L.force p;()))
      in PEs p end
  |_=>Null
 fun parseFile text=
   let val result=S.map line(S.fromList(lines text))
       fun spine values=case L.force values of S.Nil=>()
         |S.Cons(_,rest)=>spine rest
       val _=spine result
   in result end
 fun peEqual(PE(a,b),PE(c,d))=a=c andalso value b=value d
 fun listEqual equal xs ys=case(xs,ys)of([],[])=>true
   |(a::rest,b::tail)=>equal(a,b)andalso listEqual equal rest tail|_=>false
 fun actValues(Act(a,b,c,d,e,f))=[a,b,c,d,e,f]
 fun sparkValues(Sp(a,b,c,d,e))=[a,b,c,d,e]
 fun numEqual(a,b)=value a=value b
 fun lineEqual(Ln(p,a,s),Ln(q,b,t))=
       peEqual(L.force p,L.force q)andalso
       listEqual numEqual(actValues(L.force a))(actValues(L.force b))andalso
       listEqual numEqual(sparkValues(L.force s))(sparkValues(L.force t))
   |lineEqual(PEs p,PEs q)=peEqual(L.force p,L.force q)
   |lineEqual(Null,Null)=true|lineEqual _=false
 fun bucket(Ln(_,a,_))=(case L.force a of Act(n,_,_,_,_,_)=>n)
   |bucket _=raise Match
 fun total(Act(_,_,_,_,_,t))=t
 fun insert entry entries=L.delay(fn()=>case L.force entries of S.Nil=>L.force(S.singleton entry)
   |S.Cons(first,rest)=>
     let val old=L.force first
         val greater=if lineEqual(old,entry)then false else value(bucket old)>value(bucket entry)
     in if greater then S.Cons(L.delay(fn()=>entry),entries)
        else S.Cons(first,insert entry rest)end)
 type parameters=(pe S.stream*number*line S.stream)L.delay
 fun parameters input:parameters=
   let fun loop ordered ticks input=L.delay(fn()=>case L.force input of S.Nil=>(S.empty(),ticks,ordered)
         |S.Cons(item,rest)=>case L.force item of
             entry as Ln(_,act,_)=>L.force(loop(insert entry ordered)(maximum(ticks,total(L.force act)))rest)
           |PEs p=>
             let val remaining=loop ordered ticks rest
             in(S.cons(p,L.delay(fn()=>L.force(#1(L.force remaining)))),
                D.delay(fn()=>value(#2(L.force remaining))),
                L.delay(fn()=>L.force(#3(L.force remaining))))end
           |Null=>L.force(loop ordered ticks rest))
   in loop(S.empty())zero input end
 fun selected chosen pe=List.null chosen orelse List.exists(fn p=>peEqual(p,pe))chosen
 fun getActs chosen entries=S.concatMap(fn entry=>case entry of Ln(pe,a,_)=>
     if List.null chosen orelse selected chosen(L.force pe)then S.singleton(L.force a)else S.empty()|_=>S.empty())entries
 fun getSparks chosen entries=S.concatMap(fn entry=>case entry of Ln(pe,_,s)=>
     if List.null chosen orelse selected chosen(L.force pe)then S.singleton(L.force s)else S.empty()|_=>S.empty())entries
 fun scaleAct ticks(a as Act(n,i,r,g,f,t))=if value ticks=value t then a else
   let val factor=D.delay(fn()=>I.div(value ticks,value t))
       fun scaled x=D.delay(fn()=>I.*(value x,value factor))
   in Act(n,scaled i,scaled r,scaled g,scaled f,scaled t)end
 fun addAct(Act(_,a,b,c,d,t),Act(n,e,f,g,h,u))=Act(n,add(a,e),add(b,f),add(c,g),add(d,h),add(t,u))
 fun addSpark(Sp(n,a,b,c,d),Sp(_,e,f,g,h))=Sp(n,add(a,e),add(b,f),add(c,g),add(d,h))
 fun addPoolSpark(Sp(_,a,b,c,d),Sp(n,e,f,g,h))=Sp(n,add(a,e),add(b,f),add(c,g),add(d,h))
 fun actNumber(Act(n,_,_,_,_,_))=n
 fun sparkNumber(Sp(n,_,_,_,_))=n
 fun gatherAct state entries=L.delay(fn()=>case L.force entries of
     S.Nil=>L.force(S.fromList[state,Act(add(actNumber state,number 1),zero,zero,zero,zero,zero)])
   |S.Cons(first,rest)=>let val entry=L.force first
     in if value(actNumber state)=value(actNumber entry)then L.force(gatherAct(addAct(state,entry))rest)
        else S.Cons(L.delay(fn()=>state),gatherAct(Act(add(actNumber state,number 1),zero,zero,zero,zero,zero))entries)end)
 fun gatherSpark finalZero state entries=L.delay(fn()=>case L.force entries of
     S.Nil=>L.force(if finalZero then
       S.fromList[state,Sp(add(sparkNumber state,number 1),zero,zero,zero,zero)]else S.singleton state)
   |S.Cons(first,rest)=>let val entry=L.force first
     in if value(sparkNumber state)=value(sparkNumber entry)then L.force(gatherSpark finalZero(if finalZero then addSpark(state,entry)else addPoolSpark(state,entry))rest)
        else S.Cons(L.delay(fn()=>state),gatherSpark finalZero(Sp(add(sparkNumber state,number 1),zero,zero,zero,zero))entries)end)
 fun accumulate (step:'state->'a->'b*'state) (initial:'state) (entries:'a S.stream)=
   let fun loop state entries=L.delay(fn()=>case L.force entries of S.Nil=>(S.empty(),state)
         |S.Cons(first,rest)=>
           let val produced=L.delay(fn()=>step(L.force state)(L.force first))
               val remaining=loop(L.delay(fn()=> #2(L.force produced)))rest
           in(S.cons(L.delay(fn()=> #1(L.force produced)),
                L.delay(fn()=>L.force(#1(L.force remaining)))),
              L.delay(fn()=>L.force(#2(L.force remaining))))end)
   in loop(L.delay(fn()=>initial))entries end
end
