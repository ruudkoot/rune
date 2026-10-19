 fun maxZeroFromMinOne domains ones=maxZeroFromMinOneAux(map topRoute domains)domains ones
 fun minOneFromMaxZero domains zeros=minOneFromMaxZeroAux(map bottomRoute domains)domains zeros
 fun joinOneFrontiers xs ys=insertionSort compareFrel(foldRight(minimumAdd belowFrel)xs ys)
 fun constructorInstance mindless arguments simplestInitial usage:route=D.delay(fn()=>
   let val isCAF=case force simplestInitial of DXFunc _=>false|_=>true
       val simplest=if isCAF then cell(DXFunc(F.empty(),simplestInitial))else simplestInitial
       val recursive=case force simplest of DXFunc(_,result)=>(case force result of DXLift1 _=>false|DXLift2 _=>true
             |_=>panic"coMakeConstructorInstance:recursive")|_=>panic"coMakeConstructorInstance:recursive"
       val actual=applyDomainSubstitution usage simplest
       val(sources,target)=case force actual of Func(args,result)=>(args,result)|_=>raise Match
       val products=L.delay(fn()=>case(recursive,force target)of
          (true,Lift2 ds)=>ds|(false,Lift1 ds)=>ds
         |(true,Lift1 _)=>panic"cMCI(1)"|(false,Two)=>panic"cMCI(2)"|_=>raise Match)
       val below=case(recursive,force target)of
          (true,Lift2 _)=>F.fromList[Stop2,Up2]
         |(true,Lift1 _)=>let val point=cell(Up1(singleton(cell Zero)))
             in F.cons(cell Stop1,singleton point)end
         |(false,Lift1 _)=>singleton(cell Stop1)|(false,Two)=>singleton(cell Zero)|_=>raise Match
       val above=F.defer(fn()=>case(recursive,force target)of
          (true,Lift2 _)=>map(fn rs=>cell(UpUp2 rs))(cartesianProduct(map allRoutes(L.force products)))
         |(true,Lift1 _)=>let val point=cell(Up1(singleton(cell One)))in singleton point end
         |(false,Lift1 _)=>map(fn rs=>cell(Up1 rs))(cartesianProduct(map allRoutes(L.force products)))
         |(false,Two)=>singleton(cell One)|_=>raise Match)
       fun components point=case force point of UpUp2 rs=>if recursive then rs else raise Match
         |Up1 rs=>if not recursive then rs else raise Match|_=>raise Match
       fun magic point argument=case force argument of ConstrRec=>point
         |ConstrVar n=>nth(components point)n
       val bottoms=singleton(cell(MkFrel(map bottomRoute sources)))
       val table=F.append(map(fn p=>pair p bottoms)below)
         (map(fn p=>pair p(singleton(cell(MkFrel(map(magic p)arguments)))))above)
       val rep=generateConstructor mindless table actual
   in if isCAF then force(constantRepresentation rep)else Rep rep end)
 and generateConstructor mindless table domain:representation=D.delay(fn()=>case force domain of
    Func(arguments,target)=>(case force target of
      Two=>let val ones=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(1)"(cell One))
          val zeros=maxZeroFromMinOne arguments ones
          val arity=case force(head(F.append ones zeros))of MkFrel rs=>length rs
        in RepTwo(makeFrontier arity ones zeros)end
     |Lift1 targets=>
        let val ones=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(2)"(cell(Up1(map bottomRoute targets))))
            val zeros=maxZeroFromMinOne arguments ones
            val newTable=flatMap(fn entry=>let val(point,values)=force entry
              in case force point of Up1 rs=>singleton(pair rs values)|_=>F.empty()end)table
        in Rep1(makeFrontier(length arguments)ones zeros,generateConstructorCross mindless newTable arguments targets)end
     |Lift2 targets=>
        let val ones=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(2)"(cell Up2))
            val zeros=maxZeroFromMinOne arguments ones
            val middleOnes=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(3)"(cell(UpUp2(map bottomRoute targets))))
            val middleZeros=maxZeroFromMinOne arguments middleOnes
            val newTable=flatMap(fn entry=>let val(point,values)=force entry
              in case force point of UpUp2 rs=>singleton(pair rs values)|_=>F.empty()end)table
        in Rep2(makeFrontier(length arguments)ones zeros,makeFrontier(length arguments)middleOnes middleZeros,
              generateConstructorCross mindless newTable arguments targets)end
     |Func(more,result)=>
        let val newTable=map(fn point=>
              let val values=minimal belowFrel(flatMap(fn entry=>let val(g,minimumArgs)=force entry
                    in flatMap(fn x=>let val MkFrel xs=force x
                       in map(fn y=>let val MkFrel ys=force y in cell(MkFrel(F.append xs ys))end)
                         (minimumInverse mindless target g point)end)minimumArgs end)table)
              in pair point values end)(allRoutes result)
        in force(generateConstructor mindless newTable(cell(Func(F.append arguments more,result))))end)
   |_=>raise Match)
 and generateConstructorCross mindless table arguments targets=
   let val dimensions=length targets
       fun dimension n=
         let fun add point values acc=F.defer(fn()=>case force acc of F.Nil=>singleton(pair point(singleton values))
               |F.Cons(entry,rest)=>let val(p,groups)=force entry
                  in if equalRoute point p then F.cons(pair p(F.cons(values,groups)),rest)
                     else F.cons(entry,add point values rest)end)
             fun allRows rows acc=case force rows of F.Nil=>acc|F.Cons(entry,rest)=>
                let val(points,values)=force entry
                in allRows rest(add(nth points n)values acc)end
             val grouped=allRows table(F.empty())
             val fixed=mapSecond(fn values=>foldRight joinOneFrontiers
                 (singleton(cell(MkFrel(map topRoute arguments))))values)grouped
         in generateConstructor mindless fixed(cell(Func(arguments,nth targets n)))end
   in map dimension(intsFromTo(int 0)(subtract dimensions(int 1)))end
