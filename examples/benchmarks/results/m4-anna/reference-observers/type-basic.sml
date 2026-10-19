 fun equalTVName a b=let val(xs,ys)=force a val(zs,ws)=force b
   in equalLists equalInt xs zs andalso equalLists equalInt ys ws end
 fun compareTVName a b=let val(xs,ys)=force a val(zs,ws)=force b
   in thenCompare(compareLists compareInt xs zs)(fn()=>compareLists compareInt ys ws)end
 fun typeVariables expression=
   let fun collect expression rest=F.defer(fn()=>case force expression of TVar name=>F.cons(name,rest)
       |TArr(a,b)=>collect a(collect b rest)
       |TCons(_,args)=>force(foldRight(fn arg=>fn rest=>cell(collect arg(force rest)))(cell rest)args))
   in collect expression(F.empty())end
 fun showType expression=
   let val dictionary=unique equalTVName(typeVariables expression)
       fun position value values=case force values of F.Nil=>panic"tcShowtExpr: Type name lookup failed"
         |F.Cons(x,rest)=>if equalTVName value x then int 1 else add(int 1)(position value rest)
       fun render bracket expression=F.defer(fn()=>case force expression of
          TVar variable=>F.fromList[#" ",Char.chr(96+small(position variable dictionary))]
         |TArr(a,b)=>if bracket then F.append(name" (")(F.append(render true a)
              (F.append(name" -> ")(F.append(render false b)(name")"))))
            else F.append(render true a)(F.append(name" -> ")(render false b))
         |TCons(n,args)=>if null args andalso List.exists(fn s=>equalName n(name s))["int","bool","char"]
             then F.append(name" ")n
            else F.append(name" (")(F.append n(F.append(flatMap(render true)args)(name")"))))
   in render false expression end
 fun applySubstitution phi variable:texpr=D.delay(fn()=>
   let val value=lookupDefault equalTVName phi variable(cell(TVar variable))
   in if equalType(cell(TVar variable))value then TVar variable else force(substituteType phi value)end)
 and substituteType phi expression:texpr=D.delay(fn()=>case force expression of
      TVar variable=>force(applySubstitution phi variable)
     |TCons(n,args)=>TCons(n,map(substituteType phi)args)
     |TArr(a,b)=>TArr(substituteType phi a,substituteType phi b))
 fun composeSubstitutions second first=F.append first second
 fun deltaSubstitution variable expression=F.defer(fn()=>case force expression of TVar other=>
        (case compareTVName variable other of EQUAL=>F.empty()
          |GREATER=>singleton(pair variable(cell(TVar other)))
          |LESS=>singleton(pair other(cell(TVar variable))))
      |_=>singleton(pair variable expression))
 type substNode=(tvname D.t*texpr)F.node
 type unifyReply=(substNode,nameNode)replyNode L.delay
 fun extendSubstitution phi variable expression:unifyReply=L.delay(fn()=>
   if equalType expression(cell(TVar variable))then Ok phi
   else if not(member equalTVName variable(typeVariables expression))
     then Ok(composeSubstitutions(deltaSubstitution variable expression)phi)
   else myFail("Type error in source program:\n\nCircular substitution:\n      "^
       string(showType(cell(TVar variable)))^"\n   going to\n      "^string(showType expression)^"\n"))
 fun unify phi(a:texpr,b:texpr):unifyReply=L.delay(fn()=>case(force a,force b)of
      (TVar variable,_)=>let val resolved=applySubstitution phi variable
           val other=substituteType phi b
        in if equalType resolved(cell(TVar variable))
            then L.force(extendSubstitution phi variable other)else L.force(unify phi(resolved,other))end
     |(_,TVar _)=>L.force(unify phi(b,a))
     |(TArr(a,b),TArr(c,d))=>L.force(unifyList phi(F.cons(pair a c,singleton(pair b d))))
     |(TCons(n,args),TCons(m,others))=>if equalName n m then L.force(unifyList phi(zip args others))
        else mismatch a b
     |_=>mismatch a b)
 and mismatch a b=myFail("Type error in source program:\n\nCannot unify\n      "^
        string(showType a)^"\n   with\n      "^string(showType b)^"\n")
 and unifyList phi equations:unifyReply=L.delay(fn()=>case force equations of F.Nil=>Ok phi
      |F.Cons(equation,rest)=>case L.force(unifyList phi rest)of
         Failed message=>Failed message|Ok next=>L.force(unify next(force equation)))
 fun mapAnnotation f value=D.delay(fn()=>
   let val(annotation,node)=force value
       val mapped=D.delay(fn()=>case force node of
          AVar n=>AVar n|ANum n=>ANum n|AConstr n=>AConstr n
         |AAp(a,b)=>AAp(mapAnnotation f a,mapAnnotation f b)
         |ALam(args,e)=>ALam(args,mapAnnotation f e)
         |ALet(r,definitions,e)=>ALet(r,mapSecond(mapAnnotation f)definitions,mapAnnotation f e)
         |ACase(e,alternatives)=>ACase(mapAnnotation f e,map(fn entry=>
             let val(tag,body)=force entry val(args,e)=force body
             in pair tag(pair args(mapAnnotation f e))end)alternatives))
   in(f annotation,mapped)end)
