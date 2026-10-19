(* Independent observations of pinned original Anna functions.
   Every kernel instance is shared across its policy's semantic checks. *)
functor NofibAnnaTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibAnnaFn(D)
 structure L=BenchLazy
 val root="tests/benchmarks/data/nofib-anna/"
 fun read name=BenchApplicationTestIO.read(root^name)
 fun compare suffix expected actual=BenchApplicationTestIO.compare("nofib-anna/"^label^"/"^suffix,expected,actual)
 structure Observe=struct
  open K
 fun quoteName value="\""^string value^"\""
 fun showList show values="["^String.concatWith","(List.map show(F.toList values))^"]"
 fun namesShown values="["^String.concatWith","(List.map quoteName(
   let fun collect xs=case force xs of F.Nil=>[]|F.Cons(x,rest)=>x::collect rest
   in collect values end))^"]"
 fun observeTypeExpr value=case force value of TDefVar n=>"V"^quoteName n
   |TDefCons(n,args)=>"C("^quoteName n^","^showList(fn node=>observeTypeExpr(cell node))args^")"
 fun observeTypeDefinition(n,vars,constructors)=
   "("^String.concatWith","[quoteName n,namesShown vars,
     showList(fn(c,args)=>"("^quoteName c^","^showList(fn node=>observeTypeExpr(cell node))args^")")constructors]^")"
 fun observeCore value=case force value of EVar n=>"V"^quoteName n
   |ENum n=>"N"^signed n|EConstr n=>"C"^quoteName n
   |EAp(a,b)=>"A("^observeCore a^","^observeCore b^")"
   |ELet(recursive,bindings,body)=>"L("^String.concatWith","[
       if force recursive then"True"else"False",
       showList(fn(n,e)=>"("^quoteName n^","^observeCore e^")")bindings,observeCore body]^")"
   |ECase(e,alternatives)=>"K("^observeCore e^","^showList(fn(n,alt)=>
       let val(args,e)=force alt in"("^quoteName n^",("^namesShown args^","^observeCore e^"))"end)alternatives^")"
   |ELam(args,body)=>"F("^namesShown args^","^observeCore body^")"
 fun observeProgram value=let val(types,definitions)=force value
   in"("^showList observeTypeDefinition types^","^showList(fn(n,value)=>
      let val(args,body)=force value
      in"("^quoteName n^",("^namesShown args^","^observeCore body^"))"end)definitions^")"end
 fun showDomain d value=
   let val node=force value
       val body=case node of Two=>"Two"
         |Lift1 ds=>"Lift1 "^showList(fn node=>showDomain 0(cell node))ds
         |Lift2 ds=>"Lift2 "^showList(fn node=>showDomain 0(cell node))ds
         |Func(ds,res)=>"Func "^showList(fn node=>showDomain 0(cell node))ds^" "^showDomain 11 res
   in case node of Two=>body|_=>if d>10 then"("^body^")"else body end
 fun observeTable table=showList(fn(domain,size)=>"("^showDomain 0 domain^","^signed size^")")table
 fun observeTVName variable=let val(xs,ys)=force variable
   in"("^showList(fn n=>signed(cell n))xs^","^showList(fn n=>signed(cell n))ys^")"end
 fun observeType expression=case force expression of
    TVar variable=>"V"^observeTVName variable
   |TArr(a,b)=>"A("^observeType a^","^observeType b^")"
   |TCons(n,args)=>"C("^quoteName n^","^showList(fn node=>observeType(cell node))args^")"
 fun observeTyped(tree:typedAnnotation)=
   let val(t,node)=force tree
       val value=case force node of AVar n=>"V"^quoteName n|ANum n=>"N"^signed n
         |AConstr n=>"C"^quoteName n
         |AAp(a,b)=>"A("^observeTyped a^","^observeTyped b^")"
         |ALam(args,e)=>"F("^namesShown args^","^observeTyped e^")"
         |ALet(recursive,definitions,e)=>"L("^String.concatWith","[
             if force recursive then"True"else"False",
             showList(fn(n,e)=>"("^quoteName n^","^observeTyped e^")")definitions,observeTyped e]^")"
         |ACase(e,alternatives)=>"K("^observeTyped e^","^showList(fn(tag,value)=>
             let val(args,e)=force value
             in"("^quoteName tag^",("^namesShown args^","^observeTyped e^"))"end)alternatives^")"
   in"("^observeType t^","^value^")"end

 end
 val builtinNames=K.map(fn entry=> #1(D.force entry))K.baseAnnotations
 fun profile(profile,file)=
   let val source=read("inputs/"^file)
       val parsed=K.parseSyntax(K.lex(K.int 1)(K.input source))
       val _=compare(profile^"/parsed")(read("parsed-"^profile^".reference"))(Observe.observeProgram parsed)
       val(types,_)=D.force parsed
       val groups=K.typeDependency types
       val grouping=Observe.showList(fn(recursive,names)=>"("^(if D.force recursive then"True"else"False")^","^Observe.namesShown names^")")groups
       val _=compare(profile^"/dependency")(read("dependency-"^profile^".reference"))grouping
       val(_,atomic)=K.parseCore(K.input source)
       val(types,e)=D.force atomic
       fun finalLift(mode,pretty)=
         let val(e,parameters)=L.force(K.lambdaLift builtinNames e pretty)
             val actual="("^Observe.observeCore e^","^Observe.showList(fn(n,ps)=>"("^Observe.quoteName n^","^Observe.namesShown ps^")")parameters^")"
         in compare(profile^"/lift-"^mode)(read("lift-final-"^mode^"-"^profile^".reference"))actual end
       val _=List.app finalLift[("pretty",true),("raw",false)]
       val(e,_)=L.force(K.lambdaLift builtinNames e true)
       val(words,result)=K.checkTypes K.baseTypes(K.singleton(K.int 1),K.singleton(K.int 0))(K.pair types e)
       val _=compare(profile^"/types")(read("types-"^profile^".reference"))(K.string words)
       val(tree,environment)=case L.force result of K.Ok value=>D.force value|_=>raise Fail"source typecheck failed"
       val _=compare(profile^"/typed-tree")(read("typed-tree-"^profile^".reference"))(Observe.observeTyped tree)
       val _=compare(profile^"/eta-tree")(read("eta-tree-"^profile^".reference"))(Observe.observeTyped(K.etaAbstract tree))
       val _=compare(profile^"/type-environment")(read("type-environment-"^profile^".reference"))
          (Observe.showList(fn(n,t)=>"("^Observe.quoteName n^","^Observe.observeType t^")")environment)
       val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
       val report=K.string(K.strictAnalyze table(K.F.empty())(K.input source))
   in compare(profile^"/complete-report")(read("full-"^profile^".reference"))report end
 val _=List.app profile[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
 val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
 val _=compare"complete-lattice-table"(read"lattice-table.reference")(Observe.observeTable table)

 structure Domains=struct
 fun list f values="["^String.concatWith","(List.map f values)^"]"
 fun seq f values=let fun items values=case D.force values of K.F.Nil=>[]
       |K.F.Cons(x,rest)=>f x::items rest
   in list(fn x=>x)(items values)end
 fun pair a b="("^a^","^b^")"
 fun route value=case D.force value of K.Zero=>"0"|K.One=>"1"|K.Stop1=>"s1"
   |K.Up1 rs=>"u1"^seq route rs|K.Stop2=>"s2"|K.Up2=>"u2"|K.UpUp2 rs=>"uu2"^seq route rs
   |K.Rep r=>"r"^rep r
 and rep value=case D.force value of K.RepTwo f=>"t"^frontier f
   |K.Rep1(f,hs)=>"l"^pair(frontier f)(seq rep hs)
   |K.Rep2(f,m,hs)=>"d("^String.concatWith","[frontier f,frontier m,seq rep hs]^")"
 and frontier value=let val K.Min1Max0(a,ones,zeros)=D.force value
   in"("^String.concatWith","[K.signed a,seq frel ones,seq frel zeros]^")"end
 and frel value=let val K.MkFrel rs=D.force value in seq route rs end
 fun boolean true="True"|boolean false="False"
val cases=[(K.cell K.Two,K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty())))),(K.cell(K.Lift1(K.F.cons(K.cell K.Two,(K.F.empty())))),K.F.cons(K.cell K.Stop1,K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.Zero,(K.F.empty())))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.cell(K.Lift2(K.F.cons(K.cell K.Two,(K.F.empty())))),K.F.cons(K.cell K.Stop2,K.F.cons(K.cell K.Up2,K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.Zero,(K.F.empty())))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))))),(K.cell(K.Lift1(K.F.cons(K.cell K.Two,K.F.cons(K.cell K.Two,(K.F.empty()))))),K.F.cons(K.cell K.Stop1,K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty()))))))),(K.cell(K.Lift2(K.F.cons(K.cell K.Two,K.F.cons(K.cell K.Two,(K.F.empty()))))),K.F.cons(K.cell K.Stop2,K.F.cons(K.cell K.Up2,K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty())))))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell K.Two)),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty()))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,K.F.cons(K.cell K.Two,(K.F.empty()))),K.cell K.Two)),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty())))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty()))))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty())))((K.F.empty())))))),(K.F.empty())))))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell(K.Lift1(K.F.cons(K.cell K.Two,(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))),(K.F.empty())))))),(K.F.empty())))))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell(K.Lift2(K.F.cons(K.cell K.Two,(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))),(K.F.empty())))))),(K.F.empty())))))))))))),(K.cell(K.Func(K.F.cons(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell K.Two)),(K.F.empty())),K.cell K.Two)),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty()))))))]

 val source=TextIO.openIn(root^"domains.reference")
 val index=ref 0
 fun check phase actual=
   let val expected=case TextIO.inputLine source of SOME s=>s|NONE=>raise Fail"domain oracle EOF"
   in compare("domain-"^Int.toString(!index)^"/"^phase)expected(actual^"\n")end
 fun one(domain,values)=
   let fun pairs f=let fun outer values=case D.force values of K.F.Nil=>[]
          |K.F.Cons(x,rest)=>let fun inner ys=case D.force ys of K.F.Nil=>[]
              |K.F.Cons(y,rest)=>f x y::inner rest
            in inner values@outer rest end
         fun outerFrom xs=case D.force xs of K.F.Nil=>[]
          |K.F.Cons(x,rest)=>let fun inner ys=case D.force ys of K.F.Nil=>[]
               |K.F.Cons(y,rest)=>f x y::inner rest
            in inner values@outerFrom rest end
       in list(fn x=>x)(outerFrom values)end
   in check"routes"(seq route(K.allRoutes domain));
      check"bounds"(pair(route(K.topRoute domain))(route(K.bottomRoute domain)));
      check"predicates"(seq(fn r=>pair(boolean(K.isTopRoute r))(boolean(K.isBottomRoute r)))values);
      check"below"(pairs(fn x=>fn y=>boolean(K.belowRoute x y)));
      check"join"(pairs(fn x=>fn y=>route(K.joinRoute x y)));
      check"meet"(pairs(fn x=>fn y=>route(K.meetRoute x y)));
      check"successors"(seq(fn r=>seq route(K.successors domain r))values);
      check"predecessors"(seq(fn r=>seq route(K.predecessors domain r))values);
      index:= !index+1 end
 val _=List.app one cases
 val _=TextIO.closeIn source
 end

 structure Sizes=struct
 fun seq f values="["^String.concatWith","(List.map f(K.F.toList values))^"]"
 fun pair x y="("^x^","^y^")"

 val input=TextIO.openIn(root^"size.reference")
 val counter=ref 0
 fun check actual=
   let val expected=case TextIO.inputLine input of SOME s=>s|NONE=>raise Fail"size oracle EOF"
   in counter:= !counter+1;compare("size-"^Int.toString(!counter))expected(actual^"\n")end
val cases=[(K.cell K.Two,K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty())))),(K.cell(K.Lift1(K.F.cons(K.cell K.Two,(K.F.empty())))),K.F.cons(K.cell K.Stop1,K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.Zero,(K.F.empty())))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.cell(K.Lift2(K.F.cons(K.cell K.Two,(K.F.empty())))),K.F.cons(K.cell K.Stop2,K.F.cons(K.cell K.Up2,K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.Zero,(K.F.empty())))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))))),(K.cell(K.Lift1(K.F.cons(K.cell K.Two,K.F.cons(K.cell K.Two,(K.F.empty()))))),K.F.cons(K.cell K.Stop1,K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.Up1(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty()))))))),(K.cell(K.Lift2(K.F.cons(K.cell K.Two,K.F.cons(K.cell K.Two,(K.F.empty()))))),K.F.cons(K.cell K.Stop2,K.F.cons(K.cell K.Up2,K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.UpUp2(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty())))))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell K.Two)),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty()))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,K.F.cons(K.cell K.Two,(K.F.empty()))),K.cell K.Two)),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty())))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.One,(K.F.empty()))))),K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty()))))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 2)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,K.F.cons(K.cell K.Zero,(K.F.empty()))))),(K.F.empty())))((K.F.empty())))))),(K.F.empty())))))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell(K.Lift1(K.F.cons(K.cell K.Two,(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep1(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))),(K.F.empty())))))),(K.F.empty())))))))),(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell(K.Lift2(K.F.cons(K.cell K.Two,(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))),(K.F.empty())))))),K.F.cons(K.cell(K.Rep(K.cell(K.Rep2(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())),K.F.cons(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))),(K.F.empty())))))),(K.F.empty())))))))))))),(K.cell(K.Func(K.F.cons(K.cell(K.Func(K.F.cons(K.cell K.Two,(K.F.empty())),K.cell K.Two)),(K.F.empty())),K.cell K.Two)),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.Zero,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty())))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty()))))))),K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell(K.Rep(K.cell(K.RepTwo(K.makeFrontier(K.int 1)((K.F.empty()))(K.F.cons(K.cell(K.MkFrel(K.F.cons(K.cell K.One,(K.F.empty())))),(K.F.empty()))))))),(K.F.empty())))),(K.F.empty())))((K.F.empty())))))),(K.F.empty()))))))]

 val domains=List.map #1 cases
 fun finite roots=List.foldr(fn(x,xs)=>K.F.cons(x,xs))(K.F.empty())roots
 val two=K.cell K.Two
 fun lift1 ds=K.cell(K.Lift1(finite ds))
 fun lift2 ds=K.cell(K.Lift2(finite ds))
 fun func ds target=K.cell(K.Func(finite ds,target))
 val table=finite[K.pair(func[two,two]two)(K.int 6),K.pair(func[lift1[two]](lift1[two]))(K.int 10)]
 val groups=List.map finite[[two],[lift1[two]],[lift2[two]],[two,two],[lift1[two],two],[lift2[two],lift1[two]]]
 fun domain d=Observe.showDomain 0 d
 fun sized value=let val(d,n)=D.force value in pair(domain d)(K.signed n)end
 fun pathNode value=let val(point,cost)=value in pair(sized point)(K.signed cost)end
 val _=List.app(fn d=>check(domain(K.normalizeSizeDomain d)))domains
 val _=List.app(fn d=>check(seq(fn d=>domain(K.cell d))(K.reduceDomain d)))domains
 val _=List.app(fn d=>let val K.MkExInt(n,missing)=D.force(K.latticeCardinality table d)
      in check("MkExInt "^K.signed n^" "^seq(fn d=>domain(K.cell d))missing)end)domains
 val _=List.app(fn ds=>check(seq pathNode(K.oneSizeSequence table(K.int 20)ds)))groups
 fun oneFunction(size,domains)=pair(K.signed size)(seq(fn d=>domain(K.cell d))domains)
 fun sequence xs=seq(fn xs=>seq oneFunction(K.cell xs))xs
 val _=List.app(fn(lo,hi)=>let val(used,unused)=K.L.force(K.sizeSequence table(K.int 20)(finite groups)(K.int lo)(K.int hi))
      in check(pair(sequence used)(sequence unused))end)[(0,1000000),(3,8),(10,1)]
 val randoms=K.fromControl(K.C.take 24(K.randomIntegers(K.int 1)(K.int 2)))
 val _=check(seq(fn n=>K.signed(K.cell n))randoms)
 val roads=finite(List.map(fn(a,b,c)=>K.triple(K.int a)(K.int b)(K.int c))[(0,1,1),(0,2,1),(1,3,1),(2,3,1)])
 val path=K.shortestPath K.equalInt roads(K.int 0)(K.int 3)
 val _=check(seq(fn(n,cost)=>pair(K.signed n)(K.signed cost))path)
 val _=TextIO.closeIn input
 end

 structure Frontiers=struct
 fun list f values="["^String.concatWith","(List.map f values)^"]"
 fun seq f values=let fun items values=case D.force values of K.F.Nil=>[]
       |K.F.Cons(x,rest)=>f x::items rest
   in list(fn x=>x)(items values)end
 fun pair a b="("^a^","^b^")"
 fun route value=case D.force value of K.Zero=>"0"|K.One=>"1"|K.Stop1=>"s1"
   |K.Up1 rs=>"u1"^seq route rs|K.Stop2=>"s2"|K.Up2=>"u2"|K.UpUp2 rs=>"uu2"^seq route rs
   |K.Rep r=>"r"^rep r
 and rep value=case D.force value of K.RepTwo f=>"t"^frontier f
   |K.Rep1(f,hs)=>"l"^pair(frontier f)(seq rep hs)
   |K.Rep2(f,m,hs)=>"d("^String.concatWith","[frontier f,frontier m,seq rep hs]^")"
 and frontier value=let val K.Min1Max0(a,ones,zeros)=D.force value
   in"("^String.concatWith","[K.signed a,seq frel ones,seq frel zeros]^")"end
 and frel value=let val K.MkFrel rs=D.force value in seq route rs end
 fun boolean true="True"|boolean false="False"

 val source=TextIO.openIn(root^"frontier.reference")
 val counter=ref 0
 fun check actual=
   let val expected=case TextIO.inputLine source of SOME s=>s|NONE=>raise Fail"frontier oracle EOF"
   in counter:= !counter+1;compare("frontier-"^Int.toString(!counter))expected(actual^"\n")end
 fun finite roots=List.foldr(fn(x,xs)=>K.F.cons(x,xs))(K.F.empty())roots
 val two=K.cell K.Two
 val one=K.cell(K.Lift1(finite[two]))
 val double=K.cell(K.Lift2(finite[two]))
 val product=K.cell(K.Lift1(finite[two,two]))
 fun unary domain=let
      val function=K.cell(K.Func(finite[domain],domain))
      val body=K.cell(K.HVar(K.name"x"))
      val expression=K.cell(K.HLam(finite[K.name"x"],body))
    in(function,expression)end
 fun binary domain=let
      val function=K.cell(K.Func(finite[domain,domain],domain))
      val x=K.cell(K.HVar(K.name"x"))
      val y=K.cell(K.HVar(K.name"y"))
      val body=K.cell(K.HMeet(finite[x,y]))
      val expression=K.cell(K.HLam(finite[K.name"x",K.name"y"],body))
    in(function,expression)end
 val cases=List.map unary[two,one,double,product]@List.map binary[two,one,double]
 fun run mode naive(domain,expression)=let
      val arguments=case D.force domain of K.Func(args,_)=>args|_=>raise Fail"function"
      val upper=case D.force(K.topRoute domain)of K.Rep r=>r|_=>raise Fail"upper"
      val lower=case D.force(K.bottomRoute domain)of K.Rep r=>r|_=>raise Fail"lower"
      val bounds=K.combineBounds upper lower
      val(result,memo)=K.L.force(K.findData mode expression domain arguments arguments bounds(fn x=>x)naive(fn()=>K.F.empty())(K.F.empty()))
      val observed=pair(rep result)(seq(fn entry=>let val(args,result)=D.force entry
         in pair(seq route args)(route result)end)memo)
    in check observed end
 val _=List.app(fn mode=>List.app(fn naive=>List.app(run mode naive)cases)[false,true])[K.Safe,K.Live]
 val _=TextIO.closeIn source
 end

 structure Analysis=struct
 fun list f values="["^String.concatWith","(List.map f values)^"]"
 fun seq f values=let fun items values=case D.force values of K.F.Nil=>[]
       |K.F.Cons(x,rest)=>f x::items rest
   in list(fn x=>x)(items values)end
 fun pair a b="("^a^","^b^")"
 fun route value=case D.force value of K.Zero=>"0"|K.One=>"1"|K.Stop1=>"s1"
   |K.Up1 rs=>"u1"^seq route rs|K.Stop2=>"s2"|K.Up2=>"u2"|K.UpUp2 rs=>"uu2"^seq route rs
   |K.Rep r=>"r"^rep r
 and rep value=case D.force value of K.RepTwo f=>"t"^frontier f
   |K.Rep1(f,hs)=>"l"^pair(frontier f)(seq rep hs)
   |K.Rep2(f,m,hs)=>"d("^String.concatWith","[frontier f,frontier m,seq rep hs]^")"
 and frontier value=let val K.Min1Max0(a,ones,zeros)=D.force value
   in"("^String.concatWith","[K.signed a,seq frel ones,seq frel zeros]^")"end
 and frel value=let val K.MkFrel rs=D.force value in seq route rs end
 fun boolean true="True"|boolean false="False"
 fun oneSize(size,domains)="("^K.signed size^","^seq(fn d=>Observe.showDomain 0 d)domains^")"
 fun info value=case D.force value of
    K.SAResult(n,d,r)=>"R("^String.concatWith","[Observe.quoteName n,Observe.showDomain 0 d,route r]^")"
   |K.SASearch(mode,n,size,count)=>"S("^String.concatWith","[
       case mode of K.Safe=>"s"|K.Live=>"l",Observe.quoteName n,K.signed size,K.signed count]^")"
   |K.SASizes(n,used,unused)=>"Z("^String.concatWith","[Observe.quoteName n,seq(fn value=>oneSize(D.force value))used,
       seq(fn value=>oneSize(D.force value))unused]^")"
   |K.SAGiveUp names=>"G"^Observe.namesShown names
   |_=>raise Fail"unexpected analysis record"

 fun one(profile,file)=
   let val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
       val(_,result)=K.prepareAnalysis(read("inputs/"^file))table
       val expected=TextIO.openIn(root^"analysis-"^profile^".reference")
       val count=ref 0
       fun loop values=case D.force values of K.F.Nil=>()
         |K.F.Cons(x,rest)=>
           let val actual=info x^"\n"
               val wanted=case TextIO.inputLine expected of SOME s=>s|NONE=>raise Fail"analysis reference EOF"
           in count:= !count+1;compare(profile^"/analysis-"^Int.toString(!count))wanted actual;loop rest end
       val _=loop result
       val _=T.check("nofib-anna/"^label^"/"^profile^"/analysis-complete",fn()=>not(Option.isSome(TextIO.inputLine expected)))
   in TextIO.closeIn expected end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
 end

 val _=List.app(fn(name,want)=>T.check("nofib-anna/"^label^"/hash/"^name,fn()=>
    let val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
        val source=read("inputs/"^name)
        val actual=K.benchmark(K.input source)table
    in K.signedHash actual=want end))
   [("anna.faststdin","-887277049712337739"),("anna.stdin","2911885587254673792"),("anna.slowstdin","1779591958989696265")]
 structure Check=BenchNofibAnnaCheckFn(K)
 val _=T.check("nofib-anna/"^label^"/zero-repetitions-skip-source-and-table",fn()=>
     Check.run["0","missing-anna-source","0"]="0")
end
structure NeedAnna=NofibAnnaTestsFn(structure D=BenchNeed val label="lazy")
structure StrictAnna=NofibAnnaTestsFn(structure D=BenchStrict val label="strict")
(* Essential sharing is checked on the actual finite representation. *)
structure AnnaDemand=BenchNofibAnnaFn(BenchNeed)
val forced=ref 0
val tail:Word64.word AnnaDemand.F.seq=BenchNeed.delay(fn()=>(forced:= !forced+1;AnnaDemand.F.Nil))
val values=AnnaDemand.F.cons(BenchNeed.delay(fn()=>0w7:Word64.word),tail)
val _=T.check("nofib-anna/lazy/unneeded-list-tail",fn()=>
   AnnaDemand.equalInt(AnnaDemand.head values)(AnnaDemand.int 7)andalso !forced=0)
val _=AnnaDemand.null(AnnaDemand.tail values)
val _=AnnaDemand.null(AnnaDemand.tail values)
val _=T.check("nofib-anna/lazy/shared-list-tail",fn()=> !forced=1)
val eof=AnnaDemand.lex(AnnaDemand.int 1)(AnnaDemand.input"")
val _=T.check("nofib-anna/singleton-eof",fn()=>
  case BenchLazy.force eof of AnnaDemand.C.Nil=>false
   |AnnaDemand.C.Cons(token,rest)=>
      let val(line,name)=BenchLazy.force token
      in AnnaDemand.equalInt line(AnnaDemand.int 999999)andalso AnnaDemand.string name="$$$"
         andalso(case BenchLazy.force rest of AnnaDemand.C.Nil=>true|_=>false)end)
