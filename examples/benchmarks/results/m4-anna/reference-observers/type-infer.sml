 fun infer definitions gamma supply(expression:core):typeReply=L.delay(fn()=>case force expression of
    ENum n=>Ok(triple(F.empty())intType(pair intType(cell(ANum n))))
   |EVar n=>inferVariable gamma supply n
   |EConstr n=>inferVariable gamma supply n
   |EAp(a,b)=>let val variable=cell supply
        val result=inferList definitions gamma(depleteTypeSupply supply)(F.cons(a,singleton b))
      in case L.force result of Failed message=>Failed message|Ok value=>
        let val(phi,types,trees)=force value
            val a=head types val b=head(tail types)
            val first=head trees val second=head(tail trees)
        in case L.force(unify phi(a,cell(TArr(b,cell(TVar variable)))))of
           Failed message=>Failed message|Ok phi=>
             let val t=applySubstitution phi variable
             in Ok(triple phi t(pair t(cell(AAp(first,second)))))end end end
   |ELam(args,e)=>(case force args of F.Nil=>L.force(infer definitions gamma supply e)
      |F.Cons(x,rest)=>let val body=if null rest then e else cell(ELam(rest,e))
        in L.force(inferLambda definitions gamma supply x body)end)
   |ELet(recursive,bindings,e)=>
       let val(names,values)=unzip bindings
       in if force recursive then L.force(inferLetrec definitions gamma supply names values e)
          else L.force(inferLet definitions gamma supply names values e)end
   |ECase(selector,alternatives)=>let val(constructors,bodies)=unzip alternatives
        val(parameters,expressions)=unzip bodies
      in L.force(inferCase definitions gamma supply selector constructors parameters expressions)end)
 and inferVariable gamma supply name=
   let val scheme=charValue gamma name
       val t=newTypeInstance supply scheme
   in Ok(triple(F.empty())t(pair t(cell(AVar name))))end
 and inferList definitions gamma supply expressions:typeListReply=L.delay(fn()=>case force expressions of
    F.Nil=>Ok(triple(F.empty())(F.empty())(F.empty()))
   |F.Cons(e,rest)=>let val(ns0,ns1)=splitTypeSupply supply
     in case L.force(infer definitions gamma ns1 e)of Failed message=>Failed message|Ok value=>
        let val(phi,t,tree)=force value
        in case L.force(inferList definitions(substituteEnvironment phi gamma)ns0 rest)of
           Failed message=>Failed message|Ok values=>
             let val(psi,types,trees)=force values
             in Ok(triple(composeSubstitutions psi phi)(F.cons(substituteType psi t,types))(F.cons(tree,trees)))end end end)
 and inferLambda definitions gamma supply x e:typeReply=L.delay(fn()=>
   let val variable=cell supply
       val env=F.cons(newBoundVariable x variable,gamma)
   in case L.force(infer definitions env(depleteTypeSupply supply)e)of
      Failed message=>Failed message|Ok value=>let val(phi,t,tree)=force value
         val t=cell(TArr(applySubstitution phi variable,t))
       in Ok(triple phi t(pair t(cell(ALam(singleton x,tree)))))end end)
 and inferLet definitions gamma supply names values e:typeReply=L.delay(fn()=>
   let val(ns0,ns1)=splitTypeSupply supply
   in case L.force(inferList definitions gamma ns1 values)of Failed message=>Failed message|Ok value=>
      let val(phi,types,trees)=force value
          val gamma=substituteEnvironment phi gamma
          val(ns0,ns1)=splitTypeSupply ns0
          val env=addTypeDeclarations gamma ns0 names types
      in L.force(finishLet phi names false(infer definitions env ns1 e)trees)end end)
 and finishLet phi names recursive(reply:typeReply)trees:typeReply=L.delay(fn()=>case L.force reply of
    Failed message=>Failed message|Ok value=>let val(psi,t,tree)=force value
       in Ok(triple(composeSubstitutions psi phi)t(pair t(cell(ALet(cell recursive,zip names trees,tree)))))end)
 and inferLetrec definitions gamma supply names values e:typeReply=L.delay(fn()=>
   let val(ns0,ns)=splitTypeSupply supply val(ns1,ns2)=splitTypeSupply ns
       val variables=newBoundVariables names ns2
   in case L.force(inferList definitions(F.append variables gamma)ns1 values)of
      Failed message=>Failed message|Ok value=>
       let val(phi,types,trees)=force value
           val vars=substituteEnvironment phi variables
           val gamma=substituteEnvironment phi gamma
           val oldTypes=map oldBoundVariable vars
       in case L.force(unifyList phi(zip types oldTypes))of Failed message=>Failed message|Ok phi=>
          let val vars=substituteEnvironment phi vars
              val gamma=substituteEnvironment phi gamma
              val types=map oldBoundVariable vars
              val(ns0,ns1)=splitTypeSupply ns0
              val env=addTypeDeclarations gamma ns0(map(fn entry=>let val(n,_)=force entry in n end)variables)types
          in L.force(finishLet phi names true(infer definitions env ns1 e)trees)end end end)
 and inferCase definitions gamma supply selector constructors parameters expressions:typeReply=L.delay(fn()=>
   let val definition=getTypeDefinition definitions constructors
       val(n,variables,alternatives)=force definition
       val expectedConstructors=map(fn entry=>let val(n,_)=force entry in n end)alternatives
       val(ns1,ns2)=splitTypeSupply supply
       val newVariables=newTypeVariables definition ns2
       val combined=zip constructors(zip parameters expressions)
       val(reorderedParameters,reorderedExpressions)=unzip(reorderConstructors expectedConstructors combined)
   in if not(equalInt(length expectedConstructors)(length(unique equalName constructors)))
        then myFail"Error in source program: missing alternatives in CASE"
      else
       let val(ns1,ns2)=splitTypeSupply ns1
           val gammas=allConstructorGammas newVariables alternatives reorderedParameters
           fun rightSides supply gammas expressions=F.defer(fn()=>case(force gammas,force expressions)of
              (F.Nil,F.Nil)=>F.empty()
             |(F.Cons(g,gt),F.Cons(e,et))=>let val(s1,s2)=splitTypeSupply supply
                in F.cons(cell(infer definitions(F.append g gamma)s1 e),rightSides s2 gt et)end
             |_=>raise Match)
           val results=rightSides ns1 gammas reorderedExpressions
           val substitutions=map(fn reply=>infoSubstitution(force reply))results
           val types=map(fn reply=>infoType(force reply))results
           val rhsPhi=checkUnifier(unifyTypeSet(F.empty())types)
           val selectorReply=infer definitions gamma ns2 selector
           val selectorPhi=infoSubstitution selectorReply
           val selectorType=infoType selectorReply
           val selectorTree=infoTree selectorReply
           val phi=mergeSubstitutions(F.append(concat substitutions)(F.append rhsPhi selectorPhi))
           val typeVariables=map(fn entry=>let val(_,v)=force entry in v end)newVariables
           val signatureType=cell(TCons(n,map(fn v=>cell(TVar v))typeVariables))
           val expected=substituteType phi signatureType
           val lhs=checkUnifier(unify(F.empty())(expected,selectorType))
           val bigPhi=mergeSubstitutions(F.append lhs phi)
           val finalType=substituteType bigPhi(head types)
           val trees=map(fn reply=>infoTree(force reply))results
           val alternatives=zip expectedConstructors(zip reorderedParameters trees)
       in Ok(triple bigPhi finalType(pair finalType(cell(ACase(selectorTree,alternatives)))))end
   end)
