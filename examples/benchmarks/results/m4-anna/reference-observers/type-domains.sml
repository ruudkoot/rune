 fun typeToDomainExpression groups expression:dexpr=
   let val variables=insertionSort compareTVName(unique equalTVName(typeVariables expression))
       val letters=F.fromList(List.map(fn c=>F.Cons(cell c,F.empty()))(String.explode"abcdefghijklmnopqrstuvwxyz"))
       val env=zip variables letters
       fun convert expression=D.delay(fn()=>case force expression of
          TVar v=>DXVar(sureLookup equalTVName env"tx2dx_aux(1)"v)
         |TArr(a,b)=>DXFunc(singleton(convert a),convert b)
         |TCons(n,args)=>if null args andalso(equalName n(name"int")orelse equalName n(name"char"))
              then DXTwo
            else if isRecursiveType groups n then DXLift2(map convert args)
            else DXLift1(map convert args))
   in if less(int 26)(length variables)then panic"tx2dx"else normalizeDomainExpression(convert expression)end
 fun typedToDomainTree groups tree=mapAnnotation(typeToDomainExpression groups)tree
 fun getDomainInstantiations simplest usage=
   let
     fun get basis usage=F.defer(fn()=>case(force basis,force usage)of
        (DXVar n,_)=>singleton(pair n(defaultDomain usage))
       |(DXTwo,DXTwo)=>F.empty()
       |(DXLift1 xs,DXLift1 ys)=>concat(zipExact get xs ys)
       |(DXLift2 xs,DXLift2 ys)=>concat(zipExact get xs ys)
       |(DXFunc(args,result),DXFunc(others,res))=>
          let val arity=length args val usedArity=length others
              val supplied=F.defer(fn()=>if less arity usedArity then take arity others else others)
              val resultUsage=D.delay(fn()=>force(if less arity usedArity
                then cell(DXFunc(drop arity others,res))else res))
          in F.append(get result resultUsage)(concat(zipExact get args supplied))end
       |_=>raise Match)
     fun consistent acc substitutions=case force substitutions of F.Nil=>acc|F.Cons(entry,rest)=>
        let val(n,domain)=force entry
            fun find acc=case force acc of F.Nil=>NONE|F.Cons(entry,rest)=>
              let val(k,value)=force entry in if equalName k n then SOME value else find rest end
        in case find acc of NONE=>consistent(F.cons(entry,acc))rest
          |SOME other=>if equalDomain domain other then consistent acc rest else panic"txGetInstantiations"end
   in consistent(F.empty())(get simplest usage)end
