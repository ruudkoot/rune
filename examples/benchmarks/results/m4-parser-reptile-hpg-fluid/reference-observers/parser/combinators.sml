 fun pgItem wanted env tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail eof
   |C.Cons(token,rest)=>let val(_,_,tag,value)=L.force token
      in if tag=wanted then POk(env,rest,value)else PFail token end)
 fun pgAlts parsers env tokens=L.delay(fn()=>
   let fun further first second=
         let val l1=tokenLine first val l2=tokenLine second
         in if l2>l1 then second else if l1>l2 then first
            else let val n1=tokenColumn first val n2=tokenColumn second
                 in if n1>n2 then first else second end end
       fun loop [] best=PFail best
         |loop(p::ps)best=case L.force(p env tokens)of PFail next=>loop ps(further next best)|success=>success
   in loop parsers(L.delay(fn()=>L.force(firstToken tokens)))end)
 fun pgThen2 combine p1 p2 env tokens=L.delay(fn()=>case L.force(p1 env tokens)of PFail error=>PFail error
   |POk(e1,t1,a)=>(case L.force(p2 e1 t1)of PFail error=>PFail error
     |POk(e2,t2,b)=>POk(e2,t2,D.delay(fn()=>D.force(combine a b)))))
 fun pgThen3 combine p1 p2 p3 env tokens=L.delay(fn()=>case L.force(p1 env tokens)of PFail error=>PFail error
   |POk(e1,t1,a)=>(case L.force(p2 e1 t1)of PFail error=>PFail error
     |POk(e2,t2,b)=>(case L.force(p3 e2 t2)of PFail error=>PFail error
       |POk(e3,t3,c)=>POk(e3,t3,D.delay(fn()=>D.force(combine a b c))))))
 fun pgThen4 combine p1 p2 p3 p4 env tokens=L.delay(fn()=>case L.force(p1 env tokens)of PFail error=>PFail error
   |POk(e1,t1,a)=>(case L.force(p2 e1 t1)of PFail error=>PFail error
     |POk(e2,t2,b)=>(case L.force(p3 e2 t2)of PFail error=>PFail error
       |POk(e3,t3,c)=>(case L.force(p4 e3 t3)of PFail error=>PFail error
         |POk(e4,t4,d)=>POk(e4,t4,D.delay(fn()=>D.force(combine a b c d)))))))
 fun pgApply convert parser env tokens=L.delay(fn()=>case L.force(parser env tokens)of
      PFail error=>PFail error|POk(e,t,value)=>POk(e,t,D.delay(fn()=>D.force(convert value))))
 fun pgZeroOrMore parser env tokens=L.delay(fn()=>case L.force(parser env tokens)of
      PFail _=>POk(env,tokens,F.empty())
     |POk(e1,t1,value)=>(case L.force(pgZeroOrMore parser e1 t1)of
         PFail _=>POk(e1,t1,one value)
        |POk(e2,t2,values)=>POk(e2,t2,F.cons(value,values))))
 fun pgOneOrMore parser=pgThen2 cons parser(pgZeroOrMore parser)
 fun pgTwoOrMoreWithSep parser sep=
   pgThen4(fn a=>fn _=>fn b=>fn rest=>F.cons(a,F.cons(b,rest)))parser sep parser
      (pgZeroOrMore(pgThen2 select2 sep parser))
 fun pgOneOrMoreWithSep parser sep=pgThen2 cons parser(pgZeroOrMore(pgThen2 select2 sep parser))
 fun pgEmpty value env tokens=L.delay(fn()=>POk(env,tokens,value))
 fun pgZeroOrMoreWithSep parser sep=pgAlts[
      pgOneOrMoreWithSep parser sep,pgApply one parser,pgEmpty(F.empty())]
 fun pgOptional parser env tokens=L.delay(fn()=>case L.force(parser env tokens)of
      PFail _=>POk(env,tokens,D.delay(fn()=>NONE))
     |POk(e,t,value)=>POk(e,t,D.delay(fn()=>SOME value)))
 fun pgGetLineNumber parser env tokens=L.delay(fn()=>
   case L.force(parser env tokens)of PFail error=>PFail error
    |POk(e,t,value)=>POk(e,t,D.delay(fn()=>(D.delay(fn()=>tokenLine(firstToken tokens)),value))))
 fun pgEatEnd env tokens=L.delay(fn()=>case L.force tokens of C.Nil=>POk(env,tokens,cell())
   |C.Cons(token,rest)=>let val(_,_,tag,_)=L.force token
      in POk(env,if tag=X.Lsemi orelse tag=X.Lrbrace then rest else tokens,cell())end)
 fun pgDeclList parser=pgThen3(fn _=>fn values=>fn _=>values)
   (pgItem X.Llbrace)(pgOneOrMoreWithSep parser(pgItem X.Lsemi))pgEatEnd
