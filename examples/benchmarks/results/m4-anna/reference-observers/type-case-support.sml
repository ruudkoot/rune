 fun equalTypeDefExpr a b=case(force a,force b)of(TDefVar n,TDefVar m)=>equalName n m
   |(TDefCons(n,xs),TDefCons(m,ys))=>equalName n m andalso equalLists equalTypeDefExpr xs ys|_=>false
 fun equalTypeDefinition a b=
   let val(n,vars,constructors)=force a val(m,others,alternatives)=force b
       fun equalAlternative a b=let val(n,xs)=force a val(m,ys)=force b
         in equalName n m andalso equalLists equalTypeDefExpr xs ys end
   in equalName n m andalso equalLists equalName vars others
       andalso equalLists equalAlternative constructors alternatives end
 fun getTypeDefinition definitions constructors=
   let val candidates=flatMap(fn definition=>let val(_,_,alternatives)=force definition
         val names=map(fn entry=>let val(n,_)=force entry in n end)alternatives
       in map(fn _=>definition)(filter(fn n=>member equalName n names)constructors)end)definitions
       val distinct=unique equalTypeDefinition candidates
   in if null distinct then myFail"Undeclared constructors in use"
      else if not(null(tail distinct))then myFail"CASE expression contains mixed constructors"else head distinct end
 fun reorderConstructors names associations=map(fn n=>
   let fun find entries=case force entries of F.Nil=>
           myFail("Error in source program: undeclared constructor '"^string n^"' in CASE")
       |F.Cons(entry,rest)=>let val(k,v)=force entry in if equalName k n then v else find rest end
   in find associations end)names
 fun constructorGamma newVariables alternative parameters=
   let val(_,args)=force alternative
       val types=map(fn expression=>cell(Scheme(F.empty(),typeDefinitionSubstitution newVariables expression)))args
   in zip parameters types end
 fun allConstructorGammas newVariables alternatives parameters=F.defer(fn()=>case(force alternatives,force parameters)of
    (F.Nil,F.Nil)=>F.empty()
   |(F.Cons(alt,at),F.Cons(args,pt))=>F.cons(constructorGamma newVariables alt args,
       allConstructorGammas newVariables at pt)
   |_=>raise Match)
 type typedAnnotation=(nameNode,typeNode)ann
 type typedAnnotationNode=typeNode D.t*(nameNode,typeNode)annNode D.t
 type typeInfo=subst*texpr*typedAnnotation
 type typeReply=(typeInfo,nameNode)replyNode L.delay
 type typeListInfo=subst*typeNode F.seq*typedAnnotationNode F.seq
 type typeListReply=(typeListInfo,nameNode)replyNode L.delay
 fun info(reply:typeReply)=case L.force reply of Ok value=>force value
    |Failed message=>panic("tcDeOkSel: "^string message)
 fun infoSubstitution reply=let val(phi,_,_)=info reply in phi end
 fun infoType reply=let val(_,t,_)=info reply in t end
 fun infoTree reply=let val(_,_,tree)=info reply in tree end
 val intType=cell(TCons(name"int",F.empty()))
 val boolType=cell(TCons(name"bool",F.empty()))
