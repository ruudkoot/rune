functor BenchTransformFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 type text=char F.seq
 datatype token=NUMB of text|NAME of text|SYMB of text|STR of text|PRAG of text|ERR of text|LAYOUT
 datatype defNode=Caf of text F.seq*expr|Def of text*text F.seq*expr*whereExpr
 and whereNode=Where of program|NoWhere
 and exprNode=Tail of int D.t*expr|Cons of int D.t*expr*expr
   |Map of int D.t*text*expr F.seq|Maps of int D.t*text*text*expr*expr F.seq
   |Ap of text*expr F.seq|Tuple of expr F.seq|Var of text|Lit of text
 withtype def=defNode D.t
 and whereExpr=whereNode D.t
 and expr=exprNode D.t
 and program=defNode D.t F.seq
 type quad=text*text F.seq*text*program
 fun text s=F.fromList(String.explode s)
 fun list xs=F.fromList xs
 fun empty()=F.empty()
 fun one x=F.cons(D.delay(fn()=>x),F.empty())
 fun cons x xs=F.cons(D.delay(fn()=>x),xs)
 fun number cell=D.delay(fn()=>D.force(text(String.map(fn #"~"=> #"-"|c=>c)(Int.toString(D.force cell)))))
 fun append xs ys=F.append xs ys
 fun concat texts=D.delay(fn()=>case D.force texts of F.Nil=>F.Nil
   |F.Cons(x,rest)=>D.force(append(D.force x)(concat rest)))
 fun map f xs=F.map f xs
 fun reverse xs=F.foldl(fn acc=>fn x=>cons x acc)(empty())xs
 fun head xs=case D.force xs of F.Cons(x,_)=>D.force x|F.Nil=>raise Empty
 fun tail xs=case D.force xs of F.Cons(_,rest)=>rest|F.Nil=>raise Empty
 fun null xs=case D.force xs of F.Nil=>true|_=>false
 fun foldr f initial xs=D.delay(fn()=>case D.force xs of F.Nil=>D.force initial
   |F.Cons(x,rest)=>D.force(f x(foldr f initial rest)))
 fun filter p xs=F.filter p xs
 fun compareChars xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>0
   |(F.Nil,_)=> ~1|(_,F.Nil)=>1
   |(F.Cons(a,rest),F.Cons(b,tail))=>
       let val order=Char.ord(D.force a)-Char.ord(D.force b)
       in if order=0 then compareChars rest tail else order end
 fun equal xs ys=compareChars xs ys=0
 fun member cmp xs value=case D.force xs of F.Nil=>false
   |F.Cons(x,rest)=>cmp value(D.force x)=0 orelse member cmp rest value
 fun all p xs=case D.force xs of F.Nil=>true
   |F.Cons(x,rest)=>p(D.force x)andalso all p rest
 fun takeWhile p xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if p(D.force x)then F.Cons(x,takeWhile p rest)else F.Nil)
 fun dropWhile p xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if p(D.force x)then D.force(dropWhile p rest)else F.Cons(x,rest))
 fun fromInt n=D.delay(fn()=>n)
 fun caf vars expr=D.delay(fn()=>Caf(vars,expr))
 fun def name vars expr whereExpr=D.delay(fn()=>Def(name,vars,expr,whereExpr))
 fun whereExpr program=D.delay(fn()=>Where program)
 fun noWhere()=D.delay(fn()=>NoWhere)
 fun var name=D.delay(fn()=>Var name)
 fun lit value=D.delay(fn()=>Lit value)
 fun tuple values=D.delay(fn()=>Tuple values)
 fun ap name values=D.delay(fn()=>Ap(name,values))
 fun tailExpr label expr=D.delay(fn()=>Tail(label,expr))
 fun consExpr label state expr=D.delay(fn()=>Cons(label,state,expr))
 fun mapExpr label name values=D.delay(fn()=>Map(label,name,values))
 fun mapsExpr label first last state values=D.delay(fn()=>Maps(label,first,last,state,values))
 fun listCompare cmp xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>0
   |(F.Nil,_)=> ~1|(_,F.Nil)=>1
   |(F.Cons(a,rest),F.Cons(b,tail))=>
      let val order=cmp(D.force a)(D.force b)
      in if order=0 then listCompare cmp rest tail else order end
 fun combine []=0|combine(first::rest)=let val n=first()in if n=0 then combine rest else n end
 fun exprOrder(Tail _)=1|exprOrder(Cons _)=2|exprOrder(Map _)=3|exprOrder(Maps _)=4
   |exprOrder(Ap _)=5|exprOrder(Tuple _)=6|exprOrder(Var _)=7|exprOrder(Lit _)=8
 fun intCompare(a:int D.t)(b:int D.t)=D.force a-D.force b
 fun compareExpr x y=
   let val a=D.force x val b=D.force y
       val order=exprOrder a-exprOrder b
   in if order<>0 then order else case(a,b)of
      (Tail(p,e),Tail(q,f))=>combine[fn()=>intCompare p q,fn()=>compareExpr e f]
     |(Cons(p,s,e),Cons(q,t,f))=>combine[fn()=>intCompare p q,fn()=>compareExpr s t,fn()=>compareExpr e f]
     |(Map(p,f,args),Map(q,g,args'))=>combine[fn()=>intCompare p q,fn()=>compareChars f g,fn()=>listCompare compareExpr args args']
     |(Maps(p,f,g,s,args),Maps(q,f',g',s',args'))=>combine[
         fn()=>intCompare p q,fn()=>compareChars f f',fn()=>compareChars g g',
         fn()=>compareExpr s s',fn()=>listCompare compareExpr args args']
     |(Ap(f,args),Ap(g,args'))=>combine[fn()=>compareChars f g,fn()=>listCompare compareExpr args args']
     |(Tuple args,Tuple args')=>listCompare compareExpr args args'
     |(Var a,Var b)=>compareChars a b
     |(Lit a,Lit b)=>compareChars a b
     |_=>raise Fail"transform expression comparison invariant"end
 fun compareDef x y=case(D.force x,D.force y)of
      (Caf(args,e),Caf(args',e'))=>combine[fn()=>listCompare compareChars args args',fn()=>compareExpr e e']
     |(Caf _,Def _)=> ~1
     |(Def(f,args,e,w),Def(g,args',e',w'))=>combine[fn()=>compareChars f g,
        fn()=>listCompare compareChars args args',fn()=>compareExpr e e',fn()=>compareWhere w w']
     |(Def _,Caf _)=>1
 and compareWhere x y=case(D.force x,D.force y)of
      (Where a,Where b)=>listCompare compareDef a b|(Where _,NoWhere)=> ~1
     |(NoWhere,NoWhere)=>0|(NoWhere,Where _)=>1
 fun merge unique cmp xs ys=D.delay(fn()=>case D.force xs of F.Nil=>D.force ys
   |F.Cons(a,rest)=>(case D.force ys of F.Nil=>F.Cons(a,rest)
      |F.Cons(b,tail)=>
       let val order=cmp(D.force a)(D.force b)
       in if order<0 orelse(order=0 andalso not unique)then F.Cons(a,merge unique cmp rest ys)
          else if order=0 then F.Cons(a,merge unique cmp rest tail)
          else F.Cons(b,merge unique cmp xs tail)end))
 fun sort unique cmp xs=D.delay(fn()=>
   let val size=F.length xs val middle=size div 2
   in if size<=1 then D.force xs else D.force(merge unique cmp(sort unique cmp(F.take middle xs))(sort unique cmp(F.drop middle xs)))end)
 fun removeOne cmp value xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if cmp(D.force x)(D.force value)=0 then D.force rest
      else F.Cons(x,removeOne cmp value rest))
 fun remove cmp xs ys=D.delay(fn()=>case D.force ys of F.Nil=>D.force xs
   |F.Cons(y,rest)=>D.force(remove cmp(removeOne cmp y xs)rest))
 fun uniqueNames names=sort true compareChars names
 fun uniqueDefs defs=sort true compareDef defs
 fun removeNames names removed=remove compareChars names removed
 fun removeDefs defs removed=remove compareDef defs removed
 fun choose f values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(x,rest)=>(case f(D.force x)of NONE=>D.force(choose f rest)
      |SOME value=>F.Cons(D.delay(fn()=>value),choose f rest)))
 fun flatMap f values=concat(map f values)
 fun singleCaf definition=case D.force definition of
     Caf(names,e)=>(case D.force names of F.Cons(name,rest)=>if null rest then SOME(D.force name,e)else NONE|F.Nil=>NONE)
    |_=>NONE
 fun cafs program=choose(fn definition=>case singleCaf definition of SOME(name,e)=>SOME(caf(one name)e)|NONE=>NONE)program
 fun vars expr=D.delay(fn()=>D.force(
   case D.force expr of Tail(_,e)=>vars e|Cons(_,_,e)=>vars e
    |Map(_,_,args)=>concat(map vars args)|Maps(_,_,_,_,args)=>concat(map vars args)
    |Ap(_,args)=>concat(map vars args)|Tuple args=>concat(map vars args)
    |Var name=>one name|Lit _=>empty()))
 fun rhsVars program=uniqueNames(concat(choose(fn definition=>case D.force definition of Caf(_,e)=>SOME(vars e)|_=>NONE)program))
 fun bound program=uniqueNames(choose(fn definition=>case singleCaf definition of SOME(name,_)=>SOME name|NONE=>NONE)program)
 fun free program=removeNames(rhsVars program)(bound program)
 fun unused program=removeNames(bound program)(rhsVars program)
 fun substitute program environment=map(fn definition=>subDef definition environment)program
 and subDef definition environment=D.delay(fn()=>case D.force definition of
     Caf(names,e)=>Caf(names,subExpr e environment)
    |Def(name,args,e,w)=>Def(name,args,subExpr e environment,subWhere w environment))
 and subWhere wherePart environment=D.delay(fn()=>case D.force wherePart of NoWhere=>NoWhere
    |Where program=>Where(substitute program environment))
 and subExpr expr environment=D.delay(fn()=>case D.force expr of
     Tail(p,e)=>Tail(p,subExpr e environment)
    |Cons(p,s,e)=>Cons(p,subExpr s environment,subExpr e environment)
    |Map(p,name,args)=>Map(p,name,map(fn e=>subExpr e environment)args)
    |Maps(p,f,g,s,args)=>Maps(p,f,g,subExpr s environment,map(fn e=>subExpr e environment)args)
    |Ap(name,args)=>Ap(name,map(fn e=>subExpr e environment)args)
    |Tuple args=>Tuple(map(fn e=>subExpr e environment)args)
    |Lit value=>Lit value
    |Var name=>
       let val matches=map #2(filter(fn(other,_)=>equal other name)environment)
       in if null matches then Var name else D.force(head matches)end)
 val output=text"output"
 fun replacements program=
   let fun selects want definition=case singleCaf definition of NONE=>NONE|SOME(name,e)=>
        (case D.force e of Var _=>if equal name output=want then SOME(caf(one name)e)else NONE|_=>NONE)
       val equalities=choose(selects false)program
       val outputs=choose(selects true)program
       fun pair definition=case singleCaf definition of SOME pair=>pair|NONE=>raise Fail"transform replacement invariant"
   in(map pair equalities,map pair outputs,removeDefs(removeDefs program equalities)outputs)end
 fun eqDef definition=D.delay(fn()=>case D.force definition of
     Caf(names,e)=>Caf(names,e)
    |Def(name,args,e,w)=>(case D.force w of NoWhere=>Def(name,args,e,w)
       |Where definitions=>
           let val(reps,_,rest)=replacements definitions
           in Def(name,args,subExpr e reps,whereExpr(substitute rest reps))end))
 fun replaceOutput newName program=D.delay(fn()=>case D.force program of F.Nil=>F.Nil
   |F.Cons(definition,rest)=>
      (case singleCaf(D.force definition)of NONE=>raise Fail"transform output replacement invariant"
       |SOME(oldName,e)=>if equal oldName newName then
            F.Cons(D.delay(fn()=>caf(one output)e),rest)
         else F.Cons(D.delay(fn()=>caf(one oldName)e),replaceOutput newName rest)))
 fun equalities program=D.delay(fn()=>
   let val(reps,outs,rest)=replacements program
   in if null outs then D.force(substitute(map eqDef rest)reps)
      else case D.force outs of F.Cons(pair,tail)=>
        if not(null tail)then raise Fail"transform output alias invariant"
        else let val(name,e)=D.force pair
             in if not(equal name output)then raise Fail"transform output alias name"
                else case D.force e of Var newName=>
                   D.force(substitute(map eqDef(replaceOutput newName rest))
                      (append reps(one(newName,var output))))
                 |_=>raise Fail"transform output alias expression"end
       |_=>raise Fail"transform output alias invariant"end)
 fun cafSort program=D.delay(fn()=>case D.force program of F.Nil=>F.Nil
   |F.Cons(definition,rest)=>
      (case singleCaf(D.force definition)of NONE=>raise Fail"transform CAF-sort invariant"
       |SOME(name,e)=>
        let fun select order definition=case singleCaf definition of NONE=>NONE|SOME(other,rhs)=>
              if order(compareExpr rhs e)then SOME(caf(one other)rhs)else NONE
            val less=choose(select(fn n=>n<0))rest
            val greater=choose(select(fn n=>n>0))rest
            val same=choose(fn definition=>case singleCaf definition of NONE=>NONE|SOME(other,rhs)=>
                 if compareExpr rhs e=0 then SOME other else NONE)rest
            val names=uniqueNames(cons name same)
            val first=head names
            val aliases=map(fn name=>caf(one name)(var first))(tail names)
        in D.force(append(cafSort less)(append(cons(caf(one first)e)aliases)(cafSort greater)))end))
 fun sorted program=
   let val constants=cafs program val rest=removeDefs program constants
   in equalities(append(cafSort constants)(uniqueDefs rest))end
 fun use program=useProgram(one output)program
 and useProgram always program=
   let val constants=cafs program val rest=removeDefs program constants
       val used=append always(removeNames(uniqueNames(append always(rhsVars constants)))always)
       fun matching name=choose(fn definition=>case singleCaf definition of NONE=>NONE|SOME(other,e)=>
           if equal other name then SOME(caf(one other)e)else NONE)program
   in map usedDef(append(flatMap matching used)rest)end
 and usedDef definition=D.delay(fn()=>case D.force definition of
      Caf(names,e)=>Caf(names,e)
     |Def(name,args,e,w)=>(case D.force w of NoWhere=>Def(name,args,e,w)
        |Where program=>Def(name,args,e,whereExpr(useProgram(empty())program))))
 fun cat values=concat(list values)
 fun separated render separator values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(x,rest)=>D.force(append(render(D.force x))(concat(map(fn x=>append separator(render x))rest))))
 fun indent values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(c,rest)=>if D.force c= #"\n"then
       if null rest then F.Cons(c,empty())
       else F.Cons(c,cons #" "(cons #" "(indent rest)))
     else F.Cons(c,indent rest))
 fun printProgram program=separated printDef(text"\n")program
 and printDef definition=D.delay(fn()=>D.force(
   case D.force definition of
      Caf(vars,expr)=>
       if not(null vars)andalso null(tail vars)then cat[head vars,text"\t= ",printExpr expr,text";"]
       else cat[text"(",separated(fn v=>v)(text",")vars,text")\t= ",printExpr expr,text";"]
     |Def(name,vars,expr,wherePart)=>
       (case D.force wherePart of NoWhere=>cat[name,text" ",separated(fn v=>v)(text" ")vars,text"\t= ",printExpr expr,text";"]
        |Where definitions=>cat[name,text" ",separated(fn v=>v)(text" ")vars,text"\n= ",printExpr expr,
           indent(cat[text"\nwhere\n",printProgram definitions]),text";"])))
 and printExpr expr=D.delay(fn()=>D.force(
   case D.force expr of
      Tail(_,e)=>cat[text"(tl ",printExpr e,text")"]
     |Cons(_,state,e)=>cat[text"((:) ",printExpr state,text" ",printExpr e,text")"]
     |Map(_,name,args)=>cat[text"(map_",number(fromInt(F.length args)),text" ",name,text" ",printExprs args,text")"]
     |Maps(_,first,last,state,args)=>cat[text"(maps_",number(fromInt(F.length args)),text" ",first,text" ",last,
         text" ",printExpr state,text" ",printExprs args,text")"]
     |Ap(name,args)=>cat[text"(",name,text" ",printExprs args,text")"]
     |Tuple values=>if null values then text"()"else
         if null(tail values)then printExpr(head values)
         else cat[text"(",separated printExpr(text",")values,text")"]
     |Var name=>name|Lit value=>value))
 and printExprs exprs=separated printExpr(text" ")exprs
fun parsedCases()=list [(text "simple",list [caf (list [text "v"]) (mapExpr (fromInt 1) (text "inc") (list [var (text "output")])),caf (list [text "output"]) (consExpr (fromInt 1) (lit (text "1")) (var (text "v")))]),(text "fib",list [caf (list [text "output"]) (consExpr (fromInt 1) (lit (text "0")) (var (text "b"))),caf (list [text "b"]) (consExpr (fromInt 1) (lit (text "1")) (var (text "c"))),caf (list [text "c"]) (mapExpr (fromInt 1) (text "(+)") (list [var (text "output"),var (text "b")]))]),(text "fibsum",list [caf (list [text "a"]) (consExpr (fromInt 1) (lit (text "0")) (var (text "b"))),caf (list [text "b"]) (consExpr (fromInt 1) (lit (text "1")) (var (text "c"))),caf (list [text "c"]) (mapExpr (fromInt 1) (text "(+)") (list [var (text "a"),tailExpr (fromInt 1) (var (text "a"))])),caf (list [text "output"]) (mapsExpr (fromInt 1) (text "(+)") (text "(+)") (lit (text "0")) (list [var (text "a")]))]),(text "tailtest",list [caf (list [text "b"]) (tailExpr (fromInt 1) (var (text "output"))),caf (list [text "a"]) (consExpr (fromInt 1) (lit (text "2")) (var (text "b"))),caf (list [text "output"]) (mapsExpr (fromInt 1) (text "(*)") (text "(+)") (lit (text "0")) (list [consExpr (fromInt 1) (lit (text "1")) (var (text "a"))]))]),(text "setreset",list [def (text "one_of_three") (list [text "x",text "y",text "z"]) (var (text "x")) (noWhere()),def (text "nand") (list [text "s",text "xs",text "ys"]) (mapsExpr (fromInt 1) (text "one_of_three") (text "notand") (var (text "s")) (list [var (text "xs"),var (text "ys")])) (noWhere()),def (text "notand") (list [text "s",text "a",text "b"]) (ap (text "bnot") (list [ap (text "band") (list [var (text "a"),var (text "b")])])) (noWhere()),caf (list [text "as"]) (ap (text "nand") (list [lit (text "0"),var (text "ds"),var (text "bs")])),caf (list [text "bs"]) (ap (text "nand") (list [lit (text "1"),var (text "as"),var (text "cs")])),caf (list [text "output"]) (consExpr (fromInt 1) (lit (text "1")) (var (text "as")))]),(text "flipflop",list [def (text "one_of_two") (list [text "x",text "y"]) (var (text "x")) (noWhere()),def (text "two_of_two") (list [text "x",text "y"]) (var (text "y")) (noWhere()),def (text "one_of_three") (list [text "x",text "y",text "z"]) (var (text "x")) (noWhere()),def (text "nand") (list [text "s",text "xs",text "ys"]) (mapsExpr (fromInt 1) (text "one_of_three") (text "notand") (var (text "s")) (list [var (text "xs"),var (text "ys")])) (noWhere()),def (text "buffer") (list [text "s",text "xs"]) (mapsExpr (fromInt 1) (text "one_of_two") (text "two_of_two") (var (text "s")) (list [var (text "xs")])) (noWhere()),def (text "notand") (list [text "s",text "a",text "b"]) (ap (text "bnot") (list [ap (text "band") (list [var (text "a"),var (text "b")])])) (noWhere()),caf (list [text "a1"]) (ap (text "buffer") (list [lit (text "0"),var (text "data")])),caf (list [text "a2"]) (ap (text "buffer") (list [lit (text "0"),var (text "clock")])),caf (list [text "a3"]) (ap (text "nand") (list [lit (text "0"),var (text "a1"),var (text "a1")])),caf (list [text "a6"]) (ap (text "nand") (list [lit (text "0"),ap (text "nand") (list [lit (text "0"),var (text "a1"),var (text "a2")]),var (text "a7")])),caf (list [text "a7"]) (ap (text "nand") (list [lit (text "1"),var (text "a6"),ap (text "nand") (list [lit (text "0"),var (text "a3"),var (text "a2")])])),caf (list [text "a8"]) (ap (text "nand") (list [lit (text "0"),var (text "a2"),var (text "a2")])),caf (list [text "a11"]) (ap (text "nand") (list [lit (text "0"),ap (text "nand") (list [lit (text "0"),var (text "a6"),var (text "a8")]),var (text "output")])),caf (list [text "a12"]) (ap (text "nand") (list [lit (text "1"),var (text "a11"),ap (text "nand") (list [lit (text "0"),var (text "a8"),var (text "a7")])])),caf (list [text "output"]) (consExpr (fromInt 1) (lit (text "1")) (var (text "a12")))]),(text "wave4",list [def (text "one_of_two") (list [text "x",text "y"]) (var (text "x")) (noWhere()),def (text "two_of_two") (list [text "x",text "y"]) (var (text "y")) (noWhere()),caf (list [text "a1"]) (mapsExpr (fromInt 1) (text "one_of_two") (text "two_of_two") (var (text "mf0")) (list [var (text "a7")])),caf (list [text "a2"]) (mapsExpr (fromInt 1) (text "one_of_two") (text "two_of_two") (var (text "mg0")) (list [var (text "a8")])),caf (list [text "a3"]) (mapExpr (fromInt 1) (text "first_borders") (list [var (text "a2")])),caf (list [text "a4"]) (mapExpr (fromInt 1) (text "fu") (list [var (text "a1"),var (text "a3")])),caf (list [text "a5"]) (mapExpr (fromInt 1) (text "gu") (list [var (text "a2")])),caf (list [text "a6"]) (mapExpr (fromInt 1) (text "last_borders") (list [var (text "a4")])),caf (list [text "a7"]) (mapExpr (fromInt 1) (text "fvh") (list [var (text "a4")])),caf (list [text "a8"]) (mapExpr (fromInt 1) (text "gvh") (list [var (text "a5"),var (text "a6")])),caf (list [text "a9"]) (mapExpr (fromInt 1) (text "join") (list [var (text "a1"),var (text "a2")])),caf (list [text "output"]) (consExpr (fromInt 1) (var (text "dummy_output")) (var (text "a9")))]),(text "wavestream",list [caf (list [text "ts1"]) (consExpr (fromInt 1) (var (text "tb1")) (var (text "hs1"))),caf (list [text "hs1"]) (mapExpr (fromInt 1) (text "fh") (list [var (text "vs1"),var (text "v'b1"),var (text "ur1")])),caf (list [text "vs1"]) (mapExpr (fromInt 1) (text "fv") (list [var (text "us1"),var (text "uo1"),var (text "ho1"),var (text "uor1"),var (text "ur1")])),caf (list [text "us1"]) (mapExpr (fromInt 1) (text "fu") (list [var (text "ts1"),var (text "vhl1"),var (text "vbl1"),var (text "vb1")])),caf (list [text "ur1"]) (mapExpr (fromInt 1) (text "getur") (list [var (text "us2")])),caf (list [text "uo1"]) (mapExpr (fromInt 1) (text "getuo") (list [var (text "us3")])),caf (list [text "ho1"]) (mapExpr (fromInt 1) (text "getho") (list [var (text "ts3")])),caf (list [text "uor1"]) (mapExpr (fromInt 1) (text "getuor") (list [var (text "uo2")])),caf (list [text "ts2"]) (consExpr (fromInt 1) (var (text "tb2")) (var (text "hs2"))),caf (list [text "hs2"]) (mapExpr (fromInt 1) (text "fh") (list [var (text "vs2"),var (text "v'b2"),var (text "ur2")])),caf (list [text "vs2"]) (mapExpr (fromInt 1) (text "fv") (list [var (text "us2"),var (text "uo2"),var (text "ho2"),var (text "uor2"),var (text "ur2")])),caf (list [text "us2"]) (mapExpr (fromInt 1) (text "fu") (list [var (text "ts2"),var (text "vhl2"),var (text "vbl2"),var (text "vb2")])),caf (list [text "uo2"]) (mapExpr (fromInt 1) (text "getuo") (list [var (text "us4")])),caf (list [text "ho2"]) (mapExpr (fromInt 1) (text "getho") (list [var (text "ts4")])),caf (list [text "vhl2"]) (mapExpr (fromInt 1) (text "getvhl") (list [var (text "ts1")])),caf (list [text "ts3"]) (consExpr (fromInt 1) (var (text "tb3")) (var (text "hs3"))),caf (list [text "hs3"]) (mapExpr (fromInt 1) (text "fh") (list [var (text "vs3"),var (text "v'b3"),var (text "ur3")])),caf (list [text "vs3"]) (mapExpr (fromInt 1) (text "fv") (list [var (text "us3"),var (text "uo3"),var (text "ho3"),var (text "uor3"),var (text "ur3")])),caf (list [text "us3"]) (mapExpr (fromInt 1) (text "fu") (list [var (text "ts3"),var (text "vhl3"),var (text "vbl3"),var (text "vb3")])),caf (list [text "vb3"]) (mapExpr (fromInt 1) (text "getvb") (list [var (text "ts1")])),caf (list [text "v'b3"]) (mapExpr (fromInt 1) (text "getvb") (list [var (text "vs1")])),caf (list [text "ur3"]) (mapExpr (fromInt 1) (text "getur") (list [var (text "us4")])),caf (list [text "ts4"]) (consExpr (fromInt 1) (var (text "tb4")) (var (text "hs4"))),caf (list [text "hs4"]) (mapExpr (fromInt 1) (text "fh") (list [var (text "vs4"),var (text "v'b4"),var (text "ur4")])),caf (list [text "vs4"]) (mapExpr (fromInt 1) (text "fv") (list [var (text "us4"),var (text "uo4"),var (text "ho4"),var (text "uor4"),var (text "ur4")])),caf (list [text "us4"]) (mapExpr (fromInt 1) (text "fu") (list [var (text "ts4"),var (text "vhl4"),var (text "vbl4"),var (text "vb4")])),caf (list [text "vb4"]) (mapExpr (fromInt 1) (text "getvb") (list [var (text "ts2")])),caf (list [text "v'b4"]) (mapExpr (fromInt 1) (text "getvb") (list [var (text "vs2")])),caf (list [text "vhl4"]) (mapExpr (fromInt 1) (text "getvhl") (list [var (text "ts3")])),caf (list [text "vbl4"]) (mapExpr (fromInt 1) (text "getvbl") (list [var (text "vb3")]))]),(text "hamming",list [caf (list [text "output"]) (consExpr (fromInt 1) (lit (text "1")) (mapsExpr (fromInt 1) (text "hamFo") (text "hamFs") (var (text "hams0")) (list [var (text "ham2s"),var (text "ham3s")]))),caf (list [text "ham2s"]) (ap (text "map") (list [ap (text "(*)") (list [lit (text "2")]),var (text "output")])),caf (list [text "ham3s"]) (ap (text "map") (list [ap (text "(*)") (list [lit (text "3")]),var (text "output")])),def (text "hamFo") (list [text "s",text "a",text "b"]) (ap (text "fst") (list [ap (text "hamstat") (list [var (text "s"),var (text "a"),var (text "b")])])) (noWhere()),def (text "hamFs") (list [text "s",text "a",text "b"]) (ap (text "snd") (list [ap (text "hamstat") (list [var (text "s"),var (text "a"),var (text "b")])])) (noWhere())]),(text "gamma",list [def (text "mkpair") (list [text "a",text "b"]) (tuple (list [var (text "a"),var (text "b")])) (noWhere()),def (text "perm_2") (list [text "xs"]) (ap (text "perm") (list [lit (text "2"),var (text "xs")])) (noWhere()),def (text "map_divides") (list [text "xs"]) (ap (text "map1") (list [var (text "divides"),var (text "xs")])) (noWhere()),caf (list [text "p0"]) (consExpr (fromInt 1) (var (text "lownumbers")) (var (text "p6"))),caf (list [text "p1"]) (mapExpr (fromInt 1) (text "perm_2") (list [var (text "p0")])),caf (list [text "p2"]) (mapExpr (fromInt 1) (text "map_divides") (list [var (text "p1")])),caf (list [text "p3"]) (mapExpr (fromInt 1) (text "select") (list [var (text "p2"),var (text "p1")])),caf (list [text "p4"]) (mapExpr (fromInt 1) (text "(--)") (list [var (text "p0"),var (text "p3")])),caf (list [text "p5"]) (mapExpr (fromInt 1) (text "remove1") (list [var (text "p3")])),caf (list [text "p6"]) (mapExpr (fromInt 1) (text "(++)") (list [var (text "p5"),var (text "p4")])),caf (list [text "p7"]) (mapExpr (fromInt 1) (text "or") (list [var (text "p2")])),caf (list [text "p8"]) (mapExpr (fromInt 1) (text "(~)") (list [var (text "p7")])),caf (list [text "p9"]) (mapExpr (fromInt 1) (text "mkpair") (list [var (text "p8"),var (text "p0")])),caf (list [text "output"]) (consExpr (fromInt 1) (var (text "dummy_output")) (var (text "p9")))]),(text "fft",list [caf (list [text "ns"]) (consExpr (fromInt 1) (lit (text "0")) (mapExpr (fromInt 1) (text "incmod5") (list [var (text "ns")]))),caf (list [text "ms"]) (consExpr (fromInt 1) (ap (text "#") (list [var (text "netinput"),var (text "div"),lit (text "4")])) (var (text "ms"))),caf (list [text "ixs"]) (consExpr (fromInt 1) (ap (text "reorderindex") (list [ap (text "#") (list [var (text "netinput"),var (text "div"),lit (text "4")])])) (var (text "ixs"))),caf (list [text "as"]) (consExpr (fromInt 1) (var (text "xs0")) (mapExpr (fromInt 1) (text "fftstep0") (list [var (text "ns"),var (text "ms"),var (text "ixs"),var (text "as"),var (text "bs"),var (text "cs")]))),caf (list [text "bs"]) (consExpr (fromInt 1) (var (text "xs1")) (mapExpr (fromInt 1) (text "fftstep1") (list [var (text "ns"),var (text "ms"),var (text "ixs"),var (text "cs"),var (text "bs"),var (text "as"),var (text "ds")]))),caf (list [text "cs"]) (consExpr (fromInt 1) (var (text "xs2")) (mapExpr (fromInt 1) (text "fftstep2") (list [var (text "ns"),var (text "ms"),var (text "ixs"),var (text "bs"),var (text "cs"),var (text "ds"),var (text "as")]))),caf (list [text "ds"]) (consExpr (fromInt 1) (var (text "xs3")) (mapExpr (fromInt 1) (text "fftstep3") (list [var (text "ns"),var (text "ms"),var (text "ixs"),var (text "ds"),var (text "cs"),var (text "bs")]))),caf (list [text "output"]) (mapExpr (fromInt 1) (text "concat4") (list [var (text "as"),var (text "bs"),var (text "cs"),var (text "ds")]))])]
end
