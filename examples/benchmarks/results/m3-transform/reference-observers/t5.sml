 val missing=text"?"
 val missingExpr=lit missing
 val missingArgs=one missingExpr
 val zero:int D.t=fromInt 0
 fun findMap wanted prefix program=L.delay(fn()=>case D.force program of
      F.Nil=>(false,zero,missing,missingArgs,prefix)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=L.force(findMap wanted(cons definition prefix)rest)
       in case singleCaf original of NONE=>continue original|SOME(name,e)=>
         case D.force e of Map(p,f,args)=>if equal name wanted then(true,p,f,args,append prefix rest)
           else continue(caf(one name)(mapExpr p f args))
          |_=>continue original end)
 fun findCons wanted prefix program=L.delay(fn()=>case D.force program of
      F.Nil=>(false,zero,missingExpr,missingExpr,prefix)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=L.force(findCons wanted(cons definition prefix)rest)
       in case singleCaf original of NONE=>continue original|SOME(name,e)=>
         case D.force e of Cons(p,s,x)=>if equal name wanted then(true,p,s,x,append prefix rest)
           else continue(caf(one name)(consExpr p s x))
          |_=>continue original end)
 fun notIn(a,b)pairs=case D.force pairs of F.Nil=>true
   |F.Cons(pair,rest)=>let val(x,y)=D.force pair
       in if D.force a=D.force x andalso D.force b=D.force y then false else notIn(a,b)rest end
 fun t5 program=passA(empty())program(empty())(fromInt 1)
 and passA prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(passB(empty())prefix pairs n)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue()=D.force(passA(cons original prefix)rest pairs n)
       in case singleCaf original of NONE=>continue()|SOME(name,e)=>
         if not(equal name output)then continue()else
          case D.force e of Map(k,f,args)=>
            let val v=append(text"xxv")(number n)
                val w=append(text"xxw")(number(D.delay(fn()=>D.force n+1)))
                val new=cons(caf(one output)(consExpr k(ap f(map(fn x=>ap(text"hd")(one x))args))(var v)))
                  (cons(caf(one v)(tailExpr k(var w)))
                    (cons(caf(one w)(mapExpr k f args))(append prefix rest)))
            in D.force(passA(empty())new pairs(D.delay(fn()=>D.force n+2)))end
           |_=>continue()end)
 and passB prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(passC(empty())prefix pairs n)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=D.force(passB(cons definition prefix)rest pairs n)
       in case singleCaf original of NONE=>continue original|SOME(name,e)=>
         if not(equal name output)then continue original else case D.force e of Tail(k,child)=>
          (case D.force child of Var w=>
             let val(ok,j,s,x,all)=L.force(findCons w(empty())(append prefix rest))
             in if ok then
                let val new=substitute(cons(caf(one w)(consExpr j s(var output)))all)(one(output,x))
                in D.force(passA(empty())new pairs n)end
               else continue(caf(one output)(tailExpr k(var w)))end
           |_=>continue original)
          |_=>continue original end)
 and passC prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(passD(empty())prefix pairs n)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=D.force(passC(cons definition prefix)rest pairs n)
       in case singleCaf original of NONE=>continue original|SOME(v,e)=>
          case D.force e of Tail(k,child)=>(case D.force child of Var w=>
             let val(ok,j,s,x,all)=L.force(findCons w(empty())(append prefix rest))
             in if ok then
                let val new=substitute(cons(caf(one w)(consExpr j s x))all)(one(v,x))
                in D.force(passA(empty())new pairs n)end
               else continue(caf(one v)(tailExpr k(var w)))end
           |_=>continue original)
          |_=>continue original end)
 and passD prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(append(empty())prefix)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=D.force(passD(cons definition prefix)rest pairs n)
       in case singleCaf original of NONE=>continue original|SOME(v,e)=>
          case D.force e of Tail(k,child)=>(case D.force child of Var w=>
             let val(ok,j,f,args,all)=L.force(findMap w(empty())(append prefix rest))
             in if ok andalso notIn(j,k)pairs then
                let val last=D.delay(fn()=>D.force n+F.length args-1)
                    val names=map(fn i=>append(text"xxy")(number(fromInt i)))(range n last)
                    val new=cons(caf(one w)(consExpr j(ap f(map(fn x=>ap(text"hd")(one x))args))(var v)))
                      (cons(caf(one v)(mapExpr j f(map var names)))
                         (append(map(fn(y,x)=>caf(one y)(tailExpr k x))(zip names args))all))
                in D.force(passA(empty())new(cons(j,k)pairs)(D.delay(fn()=>D.force last+1)))end
               else continue(caf(one v)(tailExpr k(var w)))end
           |_=>continue original)
          |_=>continue original end)
