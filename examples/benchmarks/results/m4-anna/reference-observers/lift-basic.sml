 fun mergeLambdas(expression:core):core=D.delay(fn()=>case force expression of
    EVar n=>EVar n|ENum n=>ENum n|EConstr n=>EConstr n
   |EAp(a,b)=>EAp(mergeLambdas a,mergeLambdas b)
   |ELet(r,definitions,body)=>ELet(r,mapSecond mergeLambdas definitions,mergeLambdas body)
   |ECase(e,alternatives)=>ECase(mergeLambdas e,map(fn entry=>let val(tag,value)=force entry
       val(args,body)=force value in pair tag(pair args(mergeLambdas body))end)alternatives)
   |ELam(args,body)=>(case force body of ELam(more,e)=>force(mergeLambdas(cell(ELam(F.append args more,e))))
       |_=>ELam(args,mergeLambdas body)))
 fun nameLambdas(expression:core):core=D.delay(fn()=>case force expression of
    EVar n=>EVar n|ENum n=>ENum n|EConstr n=>EConstr n
   |EAp(a,b)=>EAp(nameLambdas a,nameLambdas b)
   |ELam(args,body)=>let val n=name"_sc" val rhs=cell(ELam(args,nameLambdas body))
       in ELet(cell false,singleton(pair n rhs),cell(EVar n))end
   |ECase(e,alternatives)=>ECase(nameLambdas e,map(fn entry=>let val(tag,value)=force entry
       val(args,body)=force value in pair tag(pair args(nameLambdas body))end)alternatives)
   |ELet(r,definitions,body)=>ELet(r,map(fn entry=>let val(n,rhs)=force entry
       val fixed=D.delay(fn()=>case force rhs of ELam(args,e)=>ELam(args,nameLambdas e)
          |_=>force(nameLambdas rhs))
       in pair n fixed end)definitions,nameLambdas body))
 fun mapCore f(expression:core):core=D.delay(fn()=>case force expression of
    EVar n=>EVar(f n)|ENum n=>ENum n|EConstr n=>EConstr n
   |EAp(a,b)=>EAp(mapCore f a,mapCore f b)
   |ELam(args,e)=>ELam(map f args,mapCore f e)
   |ELet(r,definitions,e)=>ELet(r,map(fn entry=>let val(n,rhs)=force entry in pair(f n)(mapCore f rhs)end)definitions,mapCore f e)
   |ECase(e,alternatives)=>ECase(mapCore f e,map(fn entry=>let val(tag,value)=force entry
      val(args,body)=force value in pair tag(pair(map f args)(mapCore f body))end)alternatives))
 fun takeWhile predicate xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,takeWhile predicate rest)else F.empty())
 fun dropWhile predicate xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then dropWhile predicate rest else xs)
 fun checkUnique names=
   let fun duplicates names=F.defer(fn()=>case force names of F.Nil=>F.empty()
         |F.Cons(x,rest)=>(case force rest of F.Nil=>F.empty()|F.Cons(y,ys)=>
            if equalName x y then F.cons(x,duplicates(dropWhile(fn n=>equalName x n)ys))
              else duplicates rest))
       val duplicates=duplicates(insertionSort compareName names)
       fun showNames names="["^String.concatWith","(List.map(fn node=>
         "\""^string(cell node)^"\"")(F.toList names))^"]"
   in if null duplicates then names else myFail("Duplicate identifiers in the same scope:\n\t"^showNames duplicates)end
 fun makeName prefix supply=F.append prefix(F.append(name")")(name(signed supply)))
 fun getNames supply prefixes=
   let fun withNumbers prefixes nums=F.defer(fn()=>case force prefixes of F.Nil=>F.empty()
         |F.Cons(prefix,rest)=>case L.force nums of C.Nil=>F.empty()|C.Cons(n,nt)=>
           F.cons(makeName prefix(L.force n),withNumbers rest nt))
   in(add supply(length prefixes),withNumbers prefixes(intsFrom supply))end
 type uniqueResult=(integer*core)L.delay
 fun uniqueSupply(result:uniqueResult)=D.delay(fn()=>let val(n,_)=L.force result in force n end)
 fun uniqueBody(result:uniqueResult):core=D.delay(fn()=>let val(_,e)=L.force result in force e end)
 fun uniqueNames supply dictionary(expression:core):uniqueResult=L.delay(fn()=>case force expression of
    ENum n=>(supply,cell(ENum n))|EConstr n=>(supply,cell(EConstr n))
   |EVar n=>let fun find entries=case force entries of F.Nil=>myFail("No such variable "^String.str(Char.chr 34)^string n^String.str(Char.chr 34))
           |F.Cons(entry,rest)=>let val(k,v)=force entry
             in if equalName k n then v else find rest end
       in(supply,cell(EVar(find dictionary)))end
   |EAp(a,b)=>let val first=uniqueNames supply dictionary a
         val second=uniqueNames(uniqueSupply first)dictionary b
       in(uniqueSupply second,cell(EAp(uniqueBody first,uniqueBody second)))end
   |ELam(args,body)=>
       let val(next,names)=getNames supply(checkUnique args)
           val env=F.append(zip args names)dictionary
           val result=uniqueNames next env body
       in(uniqueSupply result,cell(ELam(names,uniqueBody result)))end
   |ECase(e,alternatives)=>
       let val selector=uniqueNames supply dictionary e
           fun alternative supply entry=
             let val(tag,value)=force entry val(args,body)=force value
                 val(next,names)=getNames supply(checkUnique args)
                 val env=F.append(zip args names)dictionary
                 val result=uniqueNames next env body
             in(uniqueSupply result,pair tag(pair names(uniqueBody result)))end
           val result=mapAccumulate alternative(uniqueSupply selector)alternatives
           val supply=D.delay(fn()=>let val(n,_)=L.force result in force n end)
           val alternatives=F.defer(fn()=>let val(_,values)=L.force result in values end)
       in(supply,cell(ECase(uniqueBody selector,alternatives)))end
   |ELet(recursive,definitions,body)=>
       let val here=checkUnique(map(fn entry=>let val(n,_)=force entry in n end)definitions)
           val(next,names)=getNames supply(checkUnique here)
           val env=F.append(zip here(map(fn n=>F.cons(cell #"_",n))names))dictionary
           fun definition supply entry=
             let val(n,rhs)=force entry
                 val result=uniqueNames supply(if force recursive then env else dictionary)rhs
             in(uniqueSupply result,pair(sureLookup equalName env"llUnique"n)(uniqueBody result))end
           val result=mapAccumulate definition next definitions
           val supply=D.delay(fn()=>let val(n,_)=L.force result in force n end)
           val final=uniqueNames supply env body
           val definitions=F.defer(fn()=>let val(_,values)=L.force result in values end)
       in(uniqueSupply final,cell(ELet(recursive,definitions,uniqueBody final)))end)
