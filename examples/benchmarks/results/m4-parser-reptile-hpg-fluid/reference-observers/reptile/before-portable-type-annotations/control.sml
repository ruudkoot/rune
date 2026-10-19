 type inputLines=text C.seq
 type transition=(text*state*inputLines)L.delay
 fun matchPrefix prefix chars=
   let fun loop [] chars=SOME chars
         |loop(c::cs)chars=case D.force chars of F.Nil=>NONE
           |F.Cons(value,rest)=>if D.force value=c then loop cs rest else NONE
   in loop(String.explode prefix)chars end
 fun dropSpaces chars=F.defer(fn()=>case D.force chars of F.Nil=>F.empty()
   |F.Cons(value,rest)=>if Char.isSpace(D.force value)then dropSpaces rest else chars)
 fun words chars=F.defer(fn()=>
   let val chars=dropSpaces chars
       fun split chars=case D.force chars of F.Nil=>(F.empty(),chars)
         |F.Cons(c,rest)=>if Char.isSpace(D.force c)then(F.empty(),chars)
            else let val(word,tail)=split rest in(F.cons(c,word),tail)end
   in case D.force chars of F.Nil=>F.empty()
     |_=>let val(word,rest)=split chars in F.cons(word,words rest)end end)
 fun readInteger chars=D.delay(fn()=>
   let val value=string chars
       val normalized=if String.isPrefix"-"value then"~"^String.extract(value,1,NONE)else value
   in case IntInf.fromString normalized of NONE=>raise Fail"Prelude.read: no parse"
      |SOME n=>W.fromLargeInt n end)
 fun stoil chars=map readInteger(words chars)
 fun breakLine chars=L.delay(fn()=>case D.force chars of F.Nil=>(F.empty(),F.empty())
   |F.Cons(c,rest)=>if D.force c= #"\n"then(F.empty(),rest)
     else let val split=breakLine rest
          in(F.cons(c,F.defer(fn()=> #1(L.force split))),F.defer(fn()=> #2(L.force split)))end)
 fun lines chars=C.defer(fn()=>case D.force chars of F.Nil=>C.empty()
   |_=>let val split=breakLine chars
           val line=F.defer(fn()=> #1(L.force split))
           val rest=F.defer(fn()=> #2(L.force split))
       in C.cons(L.delay(fn()=>line),lines rest)end)
 fun input s=lines(text s)
 fun tileprompt _=text""
 fun tilequit _ values=case L.force values of C.Nil=>true
   |C.Cons(line,_)=>case D.force(L.force line)of F.Cons(c,_)=>D.force c= #"q"|F.Nil=>false
 fun inter prompt endp transact state values=F.append(prompt state)(F.defer(fn()=>
   if endp state values then text""else
    let val step=L.delay(fn()=>L.force(transact state values))
        val response=F.defer(fn()=> #1(L.force step))
        val next=L.delay(fn()=>L.force(#2(L.force step)))
        val rest=L.delay(fn()=>L.force(#3(L.force step)))
    in F.append response(inter prompt endp transact next rest)end))
 fun tuple3 a b c=L.delay(fn()=>(a,b,c))
 fun stateFirst state=F.defer(fn()=>let val(a,_,_)=L.force state in a end)
 fun stateSecond state=D.delay(fn()=>let val(_,b,_)=L.force state in D.force b end)
 fun stateThird state=F.defer(fn()=>let val(_,_,c)=L.force state in c end)
