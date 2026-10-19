 fun sureLookup equal associations context key=case force associations of F.Nil=>
      panic("utSureLookup: key not found in "^context)
   |F.Cons(entry,rest)=>let val(k,v)=force entry
       in if equal k key then v else sureLookup equal rest context key end
 fun lookupDefault equal associations key default=case force associations of F.Nil=>default
   |F.Cons(entry,rest)=>let val(k,v)=force entry
       in if equal k key then v else lookupDefault equal rest key default end
 fun validTypeDefinitions definitions groups=
   let val arities=map(fn definition=>let val(n,vars,_)=force definition in pair n(length vars)end)definitions
       val typeNames=map(fn definition=>let val(n,_,_)=force definition in n end)definitions
       val constructorNames=flatMap(fn definition=>let val(_,_,alternatives)=force definition
          in map(fn alt=>let val(n,_)=force alt in n end)alternatives end)definitions
       fun uniqueTypes()=equalInt(length typeNames)(length(unique equalName typeNames))
       fun uniqueParameters()=all(fn definition=>let val(_,vars,_)=force definition
          in equalInt(length vars)(length(unique equalName vars))end)definitions
       fun uniqueConstructors()=equalInt(length constructorNames)(length(unique equalName constructorNames))
       fun variablesOnly expr=F.defer(fn()=>case force expr of TDefVar n=>singleton n
          |TDefCons(_,args)=>flatMap variablesOnly args)
       fun balanced()=all(fn definition=>
          let val(_,vars,alternatives)=force definition
              val used=flatMap(fn alt=>let val(_,args)=force alt in flatMap variablesOnly args end)alternatives
          in equalLists equalName(setValues(setFromList compareName vars))(setValues(setFromList compareName used))end)definitions
       fun defined()=setSubset compareName(setFromList compareName(flatMap freeTypeVariables definitions))
            (setFromList compareName typeNames)
       fun rightArity expr=case force expr of TDefVar _=>true|TDefCons(n,args)=>
           equalInt(length args)(sureLookup equalName arities
             ("paVTD"^String.str(Char.chr 96)^"rA"^String.str(Char.chr 96)^"rA")n)
             andalso all rightArity args
       fun aritiesMatch()=all(fn definition=>let val(_,_,alternatives)=force definition
          in all(fn alt=>let val(_,args)=force alt in all rightArity args end)alternatives end)definitions
       fun allVariables expr=F.defer(fn()=>case force expr of TDefVar n=>singleton n
          |TDefCons(n,args)=>F.cons(n,flatMap allVariables args))
       fun groupOf name groups=case force groups of F.Nil=>raise Match|F.Cons(entry,rest)=>
           let val(recursive,names)=force entry in if member equalName name names
              then if force recursive then names else F.empty()else groupOf name rest end
       fun simple()=all(fn definition=>let val(n,vars,alternatives)=force definition
            val used=flatMap(fn alt=>let val(_,args)=force alt in flatMap allVariables args end)alternatives
          in setSubset compareName(setFromList compareName used)
             (setFromList compareName(F.append vars(groupOf n groups)))end)definitions
   in if not(uniqueTypes())then"Non-unique type names"
      else if not(uniqueParameters())then"Non-unique parameter names"
      else if not(uniqueConstructors())then"Non-unique constructor names"
      else if not(balanced())then"Declared parameters do not match used parameters"
      else if not(defined())then"Undefined types are present"
      else if not(aritiesMatch())then"Types are used at wrong arities"
      else if not(simple())then"Perverse type definitions are present"else""end
 fun programToAtomic program=D.delay(fn()=>let val(types,definitions)=force program
       val bindings=map(fn entry=>let val(n,value)=force entry val(args,body)=force value
         in pair n(cell(ELam(args,body)))end)definitions
   in(types,cell(ELet(cell true,bindings,cell(ENum(int 42)))))end)
 fun parseCore chars=
   let val program=parseSyntax(lex(int 1)chars)
       val atomic=programToAtomic program
       val types=F.defer(fn()=>let val(types,_)=force atomic in types end)
       val groups=typeDependency types
       val errors=validTypeDefinitions types groups
   in if errors=""then(groups,atomic)else myFail errors end
