(* Open prefix of the Happy parser-generator functor. *)
functor BenchHappyFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure X=BenchHappyLexerFn(D)
 structure F=X.F
 type text=X.text
 type rule=text F.seq*text*int D.t*text option D.t
 type production=text*rule F.seq*text option D.t
 datatype directive=
    TokenType of text
   |TokenSpec of(text*text)F.seq
   |TokenName of text*text option D.t*bool D.t
   |TokenLexer of text*text
   |TokenImportedIdentity
   |TokenMonad of text*text*text*text
   |TokenNonassoc of text F.seq
   |TokenRight of text F.seq
   |TokenLeft of text F.seq
   |TokenExpect of int D.t
   |TokenError of text
   |TokenAttributetype of text
   |TokenAttribute of text*text
 datatype ast=AbsSyn of text option D.t*directive F.seq*production F.seq*text option D.t
 datatype semanticNode=
    Terminal of X.token
   |ErrorToken of int
   |S4 of ast D.t
   |S5 of production F.seq
   |S6 of production D.t
   |S7 of rule F.seq
   |S8 of rule D.t
   |S9 of text option D.t
   |S10 of directive F.seq
   |S11 of directive D.t
   |S13 of(text*text)F.seq
   |S14 of(text*text)D.t
   |S15 of text F.seq
 type semantic=semanticNode D.t
 datatype stackNode=Stk of semantic*stackNode L.delay
 type stack=stackNode L.delay
 datatype state=State of int->int->X.token->state->statesNode L.delay->stack->semantic X.parser
 and statesNode=States of state*statesNode L.delay
 type states=statesNode L.delay
 fun internal()=raise Fail"Internal Happy error\n"
 fun reverse values=F.defer(fn()=>
   let fun loop values out=case D.force values of F.Nil=>out
         |F.Cons(x,rest)=>loop rest(F.cons(x,out))
   in loop values(F.empty())end)
 fun singleton value=F.cons(value,F.empty())
 fun push value tail=L.delay(fn()=>Stk(value,tail))
 fun pop stack=case L.force stack of Stk(value,tail)=>(value,tail)
 fun pushState value tail=L.delay(fn()=>States(value,tail))
 fun popState stack=case L.force stack of States(value,tail)=>(value,tail)
 fun dropStack 0 stack=stack
   |dropStack n stack=let val(_,tail)=pop stack in dropStack(n-1)tail end
 fun dropStates 0 states=states
   |dropStates n states=let val(_,tail)=popState states in dropStates(n-1)tail end
 fun info tag value=case D.force value of Terminal(X.Info(text,id))=>
   if D.force id=tag then text else internal()|_=>internal()
 fun number value=case D.force value of Terminal(X.Num(n,id))=>
   if D.force id=X.Number then n else internal()|_=>internal()
 fun get4 value=case D.force value of S4 x=>x|_=>internal()
 fun get5 value=case D.force value of S5 x=>x|_=>internal()
 fun get6 value=case D.force value of S6 x=>x|_=>internal()
 fun get7 value=case D.force value of S7 x=>x|_=>internal()
 fun get8 value=case D.force value of S8 x=>x|_=>internal()
 fun get9 value=case D.force value of S9 x=>x|_=>internal()
 fun get10 value=case D.force value of S10 x=>x|_=>internal()
 fun get11 value=case D.force value of S11 x=>x|_=>internal()
 fun get13 value=case D.force value of S13 x=>x|_=>internal()
 fun get14 value=case D.force value of S14 x=>x|_=>internal()
 fun get15 value=case D.force value of S15 x=>x|_=>internal()
 val unitContext=X.text"()"
 val monadBind=X.text">>="
 val monadReturn=X.text"return"

 val emptyText=X.text""
 (* Source AbsSyn selectors force constructor tags, retaining attribute cells. *)
 fun select predicate dirs=
   F.defer(fn()=>case D.force dirs of F.Nil=>F.empty()
    |F.Cons(value,rest)=>(case predicate(D.force value)of NONE=>select predicate rest
      |SOME result=>F.cons(D.delay(fn()=>result),select predicate rest)))
 fun exactly message values=
   case D.force values of F.Nil=>raise Fail("no "^message)
    |F.Cons(value,rest)=>(case D.force rest of F.Nil=>D.force value
      |_=>raise Fail("multiple "^message))
 fun optional message values=
   D.delay(fn()=>case D.force values of F.Nil=>NONE
    |F.Cons(value,rest)=>(case D.force rest of F.Nil=>SOME(D.force value)
       |_=>raise Fail("multiple "^message)))
 fun getTokenType dirs=
   case D.force(select(fn TokenType t=>SOME t|_=>NONE)dirs)of F.Nil=>raise Fail"no token type given"
    |F.Cons(value,rest)=>(case D.force rest of F.Nil=>D.force value|_=>raise Fail"multiple token types")
 fun getParserNames dirs=F.filter(fn TokenName _=>true|_=>false)dirs
 fun getTokenSpec dirs=
   let fun join values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
        |F.Cons(xs,rest)=>F.append(D.force xs)(join rest))
   in join(select(fn TokenSpec xs=>SOME xs|_=>NONE)dirs)end
 fun getLexer dirs=optional"lexer directives"(select(fn TokenLexer pair=>SOME pair|_=>NONE)dirs)
 fun getImportedIdentity dirs=
   case D.force(select(fn TokenImportedIdentity=>SOME()|_=>NONE)dirs)of F.Nil=>false
    |F.Cons(_,rest)=>(case D.force rest of F.Nil=>true|_=>raise Fail"multiple importedidentity directives")
 fun getMonad dirs=
   case D.force(select(fn TokenMonad tuple=>SOME tuple|_=>NONE)dirs)of
     F.Nil=>(false,unitContext,X.text"HappyIdentity",monadBind,monadReturn)
    |F.Cons(value,rest)=>(case D.force rest of F.Nil=>
        let val(a,b,c,d)=D.force value in(true,a,b,c,d)end
      |_=>raise Fail"multiple monad directives")
 fun getPrios dirs=F.filter(fn TokenNonassoc _=>true|TokenLeft _=>true|TokenRight _=>true|_=>false)dirs
 fun getPrioNames dir=case dir of TokenNonassoc xs=>xs|TokenLeft xs=>xs|TokenRight xs=>xs|_=>internal()
 fun getExpect dirs=optional"expect directives"(select(fn TokenExpect n=>SOME(D.force n)|_=>NONE)dirs)
 fun getError dirs=optional"error directives"(select(fn TokenError text=>SOME text|_=>NONE)dirs)
 fun getAttributes dirs=select(fn TokenAttribute pair=>SOME pair|_=>NONE)dirs
 fun getAttributetype dirs=optional"attributetype directives"(select(fn TokenAttributetype text=>SOME text|_=>NONE)dirs)
 fun compareText xs ys=
   case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>EQUAL|(F.Nil,_)=>LESS|(_,F.Nil)=>GREATER
    |(F.Cons(x,xs),F.Cons(y,ys))=>(case Char.compare(D.force x,D.force y)of EQUAL=>compareText xs ys|order=>order)
 fun sameText xs ys=compareText xs ys=EQUAL
 (* Boxed immutable control arrays. Element roots remain memoized in both
  * finite-data policies; values can contain D-controlled finite data. *)
 structure A=
 struct
   datatype 'a node=ArrayNode of int*int*'a L.delay Vector.vector
   type 'a array='a node L.delay
   fun build(low:int,high:int)initial updates=
     L.delay(fn()=>
       let val count=Int.max(0,high-low+1)
           val cells=Array.array(count,initial)
           fun put(index,value)=
             if index<low orelse index>high then raise Subscript
             else Array.update(cells,index-low,value)
           val _=List.app put(updates())
       in ArrayNode(low,high,Vector.tabulate(count,fn i=>Array.sub(cells,i)))end)
   fun array bounds updates=build bounds(L.delay(fn()=>raise Fail"undefined Happy array element"))updates
   fun accum combine initial(low:int,high:int)updates=
     L.delay(fn()=>
       let val count=Int.max(0,high-low+1)
           val cells=Array.array(count,initial)
           fun put(index,value)=
             if index<low orelse index>high then raise Subscript
             else Array.update(cells,index-low,combine(Array.sub(cells,index-low))value)
           val _=List.app put(updates())
       in ArrayNode(low,high,Vector.tabulate(count,fn i=>Array.sub(cells,i)))end)
   fun bounds array=let val ArrayNode(low,high,_)=L.force array in(low,high)end
   fun sub array index=
     let val ArrayNode(low,high,values)=L.force array
     in if index<low orelse index>high then raise Subscript
        else L.force(Vector.sub(values,index-low))end
   fun fromFinite bounds values=
     let val(low,_)=bounds
         fun entries i values=case D.force values of F.Nil=>[]
           |F.Cons(value,rest)=>(i,L.delay(fn()=>value))::entries(i+1)rest
     in array bounds(fn()=>entries low values)end
   fun assocs array=
     let val(low,high)=bounds array
         fun loop i=F.defer(fn()=>if i>high then F.empty()
           else F.cons(D.delay(fn()=>(i,sub array i)),loop(i+1)))
     in loop low end
 end
 datatype associativity=LeftAssoc|RightAssoc|NonAssoc
 datatype priority=No|Prio of associativity D.t*int D.t
 type namedProduction=int D.t*int F.seq*(text*int F.seq)D.t*priority D.t
 type start=text*int D.t*int D.t*bool D.t
 datatype grammar=Grammar of{
   productions:namedProduction F.seq,
   lookupProdNo:int->namedProduction D.t,
   lookupProdsOfName:int->int F.seq,
   tokenSpecs:(int D.t*text)F.seq,
   terminals:int F.seq,nonterminals:int F.seq,starts:start F.seq,
   types:text option D.t A.array,tokenNames:text A.array,
   firstNonterm:int D.t,firstTerm:int D.t,eof:int D.t,
   priorities:(int D.t*priority D.t)F.seq,
   tokenType:text,importedIdentity:bool D.t,
   monad:(bool*text*text*text*text)L.delay,
   expect:int option D.t,attributes:(text*text)F.seq,attributeType:text,
   lexer:(text*text)option D.t,errorHandler:text option D.t}
 fun productions(Grammar{productions,...})=productions
 fun lookupProdNo(Grammar{lookupProdNo,...})=lookupProdNo
 fun lookupProdsOfName(Grammar{lookupProdsOfName,...})=lookupProdsOfName
 fun tokenSpecs(Grammar{tokenSpecs,...})=tokenSpecs
 fun terminals(Grammar{terminals,...})=terminals
 fun nonterminals(Grammar{nonterminals,...})=nonterminals
 fun starts(Grammar{starts,...})=starts
 fun types(Grammar{types,...})=types
 fun tokenNames(Grammar{tokenNames,...})=tokenNames
 fun firstNonterm(Grammar{firstNonterm,...})=D.force firstNonterm
 fun firstTerm(Grammar{firstTerm,...})=D.force firstTerm
 fun eof(Grammar{eof,...})=D.force eof
 fun priorities(Grammar{priorities,...})=priorities
 fun tokenType(Grammar{tokenType,...})=tokenType
 fun importedIdentity(Grammar{importedIdentity,...})=D.force importedIdentity
 fun monad(Grammar{monad,...})=L.force monad
 fun expect(Grammar{expect,...})=D.force expect
 fun attributes(Grammar{attributes,...})=attributes
 fun attributeType(Grammar{attributeType,...})=attributeType
 fun lexer(Grammar{lexer,...})=D.force lexer
 fun errorHandler(Grammar{errorHandler,...})=D.force errorHandler
 fun naturalSortBy cmp values=
    let fun merge xs []=xs|merge [] ys=ys
          |merge(xs as x::xr)(ys as y::yr)=if cmp(x,y)=GREATER then y::merge xs yr else x::merge xr ys
        fun descending a acc(b::bs)=if cmp(a,b)=GREATER then descending b(a::acc)bs
              else((a::acc),b::bs)
          |descending a acc []=(a::acc,[])
        fun ascending a acc(b::bs)=if cmp(a,b)<>GREATER then ascending b(fn tail=>acc(a::tail))bs
              else(acc[a],b::bs)
          |ascending a acc []=(acc[a],[])
        fun sequences(a::b::rest)=let val(run,tail)=if cmp(a,b)=GREATER
              then descending b[a]rest else ascending b(fn tail=>a::tail)rest
            in run::sequences tail end
          |sequences []=[]|sequences xs=[xs]
        fun pairs(a::b::rest)=merge a b::pairs rest|pairs xs=xs
        fun all []=[]|all[x]=x|all xs=all(pairs xs)
    in all(sequences values)end

 fun sortFinite cmp values=F.defer(fn()=>F.fromList(naturalSortBy cmp(F.toList values)))
 fun flatMap f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.append(f(D.force value))(flatMap f rest))
 fun appendMany values=flatMap(fn value=>value)values
 fun enumerate start values=
   let fun loop index values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>F.cons(D.delay(fn()=>(D.delay(fn()=>index),value)),loop(index+1)rest))
   in loop start values end
 fun length values=F.length values
 fun range low high=F.defer(fn()=>if low>high then F.empty()
      else F.cons(D.delay(fn()=>low),range(low+1)high))
 fun memberInt value values=case D.force values of F.Nil=>false
   |F.Cons(x,rest)=>D.force x=value orelse memberInt value rest
 fun memberText value values=case D.force values of F.Nil=>false
   |F.Cons(x,rest)=>sameText value(D.force x)orelse memberText value rest
 fun lookupInt value pairs=case D.force pairs of F.Nil=>NONE
   |F.Cons(pair,rest)=>let val(key,item)=D.force pair
        in if D.force key=value then SOME item else lookupInt value rest end
 fun lookupText value pairs=case D.force pairs of F.Nil=>NONE
   |F.Cons(pair,rest)=>let val(key,item)=D.force pair
        in if sameText key value then SOME item else lookupText value rest end
 fun priorityOf level dir=D.delay(fn()=>case dir of
     TokenNonassoc _=>Prio(D.delay(fn()=>NonAssoc),D.delay(fn()=>level))
    |TokenRight _=>Prio(D.delay(fn()=>RightAssoc),D.delay(fn()=>level))
    |TokenLeft _=>Prio(D.delay(fn()=>LeftAssoc),D.delay(fn()=>level))|_=>internal())
 structure NameSet=BenchHappySetFn(type item=int val compare=Int.compare)
 fun setFromNames values=
   let fun stream values=L.delay(fn()=>case D.force values of F.Nil=>NameSet.Nil
         |F.Cons(value,rest)=>NameSet.Cons(D.force value,stream rest))
   in NameSet.fromStream(stream values)end
 fun namesFromSet set=
   let fun loop stream=F.defer(fn()=>case L.force stream of NameSet.Nil=>F.empty()
         |NameSet.Cons(value,rest)=>F.cons(D.delay(fn()=>value),loop rest))
   in loop(NameSet.toAscList set)end
 fun incEmpty set=
   let fun loop stream=case L.force stream of NameSet.Nil=>false
         |NameSet.Cons(value,rest)=>value=0 orelse loop rest
   in loop(NameSet.toAscList set)end
 fun joinSymSets first values=L.delay(fn()=>
   case D.force values of F.Nil=>L.force(NameSet.singleton 0)
    |F.Cons(value,rest)=>
      let val head=first(D.force value)
      in if incEmpty head then
           L.force(NameSet.union(NameSet.filter(fn n=>n<>0)head)(joinSymSets first rest))
         else L.force head end)
 fun mkClosure equivalent update initial=
   let fun loop value=
         let val next=L.delay(fn()=>update value)
         in if equivalent value next then value else loop(L.force next)end
   in loop initial end
 fun foldBalanced combine values=
   let fun pass(a::b::c::d::rest)=combine(combine a b)(combine c d)::pass rest
         |pass(a::b::rest)=combine a b::pass rest
         |pass values=values
       fun loop []=raise Fail"can't reduce an empty list using foldb"
         |loop[value]=value
         |loop values=loop(pass values)
   in loop values end
 fun mkFirst grammar=
   let val environment=L.delay(fn()=>
         let val threshold=firstTerm grammar
             val ntNames=nonterminals grammar
             fun next env=
               let fun firstSymbol symbol=
                     if symbol=1 orelse symbol>=threshold then NameSet.singleton symbol
                     else case lookupInt symbol env of SOME set=>set
                       |NONE=>raise Fail"attempted FIRST(e) :-("
                   fun result name=L.delay(fn()=>
                     if name>=threshold then L.force(NameSet.singleton name)
                     else
                      let fun ruleFirst rule=L.delay(fn()=>
                             let val(_,rhs,_,_)=D.force(lookupProdNo grammar rule)
                             in L.force(joinSymSets firstSymbol rhs)end)
                          val sets=List.map ruleFirst(F.toList(lookupProdsOfName grammar name))
                      in L.force(foldBalanced NameSet.union sets)end)
               in F.map(fn(name,_) =>(name,result(D.force name)))env end
             fun equivalent a b=
               let fun same a b=case(D.force a,D.force b)of(F.Nil,F.Nil)=>true
                     |(F.Cons(x,xs),F.Cons(y,ys))=>
                        let val(n,s)=D.force x val(m,t)=D.force y
                        in D.force n=D.force m andalso NameSet.equal s t andalso same xs ys end
                     |_=>false
               in same a(L.force b)end
             val initial=F.map(fn name=>(D.delay(fn()=>name),NameSet.empty))ntNames
         in mkClosure equivalent next initial end)
       fun firstSymbol name=L.delay(fn()=>
         case lookupInt name(L.force environment)of NONE=>L.force(NameSet.singleton name)
          |SOME set=>L.force set)
   in joinSymSets firstSymbol end
 structure C=X.C
 type lr0Item=int D.t*int D.t
 structure ItemSet=BenchHappySetFn(type item=lr0Item
   val compare=fn((a,b),(c,d))=>case Int.compare(D.force a,D.force c)of
      EQUAL=>Int.compare(D.force b,D.force d)|order=>order)
 fun itemsFromList values=
   let fun stream values=L.delay(fn()=>case D.force values of F.Nil=>ItemSet.Nil
         |F.Cons(value,rest)=>ItemSet.Cons(D.force value,stream rest))
   in ItemSet.fromStream(stream values)end
 fun itemsToList set=
   let fun loop stream=F.defer(fn()=>case L.force stream of ItemSet.Nil=>F.empty()
         |ItemSet.Cons(value,rest)=>F.cons(D.delay(fn()=>value),loop rest))
   in loop(ItemSet.toAscList set)end
 fun findRule grammar rule dot=
   let val(_,rhs,_,_)=D.force(lookupProdNo grammar rule)
   in case D.force(F.drop dot rhs)of F.Nil=>NONE|F.Cons(value,_)=>SOME value end
 fun precalcClosure0 grammar=
   let val info=L.delay(fn()=>
         let val threshold=firstTerm grammar
             fun follow env(name,rules)=
               let fun followRule rule=L.delay(fn()=>
                     case findRule grammar rule 0 of
                       SOME nt=>if D.force nt>=3 andalso D.force nt<threshold then
                         (case lookupInt(D.force nt)env of SOME set=>L.force set|NONE=>raise Fail"followNT")
                         else L.force NameSet.empty
                      |NONE=>L.force NameSet.empty)
                   val additions=NameSet.fold(fn rule=>fn rest=>NameSet.union(followRule rule)rest)NameSet.empty rules
               in(name,NameSet.union additions rules)end
             fun update env=F.map(follow env)env
             fun equal a b=
               let fun loop a b=case(D.force a,D.force b)of(F.Nil,F.Nil)=>true
                     |(F.Cons(x,xs),F.Cons(y,ys))=>
                        let val(n,s)=D.force x val(m,t)=D.force y
                        in D.force n=D.force m andalso NameSet.equal s t andalso loop xs ys end
                     |_=>false
               in loop a(L.force b)end
             val initial=F.map(fn name=>(D.delay(fn()=>name),
                 L.delay(fn()=>L.force(setFromNames(lookupProdsOfName grammar name)))))(nonterminals grammar)
         in mkClosure equal update initial end)
       val expanded=L.delay(fn()=>F.map(fn(name,rules)=>(name,F.map(fn rule=>
           (D.delay(fn()=>rule),D.delay(fn()=>0)))(namesFromSet rules)))(L.force info))
   in fn name=>case lookupInt name(L.force expanded)of NONE=>F.empty()|SOME rules=>rules end
 fun closure0 grammar closures set=
   let val threshold=firstTerm grammar
       fun add(item as(rule,dot))rest=
         let val values=F.cons(D.delay(fn()=>item),F.defer(fn()=>
                case findRule grammar(D.force rule)(D.force dot)of
                  SOME nt=>if D.force nt>=3 andalso D.force nt<threshold then closures(D.force nt)else F.empty()
                 |NONE=>F.empty()))
         in ItemSet.union(itemsFromList values)rest end
   in ItemSet.fold add ItemSet.empty set end
 fun gotoClosure grammar set symbol=
   ItemSet.fold(fn(rule,dot)=>fn rest=>
     let val next=L.delay(fn()=>case findRule grammar(D.force rule)(D.force dot)of
           SOME token=>if D.force token=D.force symbol then
              L.force(ItemSet.singleton(rule,D.delay(fn()=>D.force dot+1)))
             else L.force ItemSet.empty
          |NONE=>L.force ItemSet.empty)
     in ItemSet.union next rest end)ItemSet.empty set
 fun cNull values=case L.force values of C.Nil=>true|_=>false
 fun cLength values=
   let fun loop n values=case L.force values of C.Nil=>n|C.Cons(_,rest)=>loop(n+1)rest
   in loop 0 values end
 fun cReverse values=C.defer(fn()=>
   let fun loop values out=case L.force values of C.Nil=>out
         |C.Cons(value,rest)=>loop rest(C.cons(value,out))
   in loop values(C.empty())end)
 fun cMap f values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
   |C.Cons(value,rest)=>C.cons(L.delay(fn()=>f(L.force value)),cMap f rest))
 fun cZip a b=C.defer(fn()=>case L.force a of C.Nil=>C.empty()
   |C.Cons(x,xs)=>(case L.force b of C.Nil=>C.empty()
      |C.Cons(y,ys)=>C.cons(L.delay(fn()=>(L.force x,L.force y)),cZip xs ys)))
 fun cFoldr f initial values=L.delay(fn()=>case L.force values of C.Nil=>L.force initial
   |C.Cons(value,rest)=>L.force(f value(cFoldr f initial rest)))
 type gotoEdge=int D.t*int L.delay
 type controlGotos=gotoEdge C.seq
 type itemWithGotos=ItemSet.set*controlGotos
 type numbered=int L.delay*controlGotos C.seq*ItemSet.set C.seq
 fun indexInto index wanted values=
   case L.force values of C.Nil=>NONE
    |C.Cons(value,rest)=>if ItemSet.equal wanted(L.force value)then SOME index
       else indexInto(L.delay(fn()=>L.force index+1))wanted rest
 fun genLR0items grammar closures=
   let val tokenValues=F.append(nonterminals grammar)(terminals grammar)
       fun tokens values=C.defer(fn()=>case D.force values of F.Nil=>C.empty()
          |F.Cons(value,rest)=>C.cons(L.delay(fn()=>value),tokens rest))
       val tokenStream=tokens tokenValues
       val startRules=C.defer(fn()=>C.fromList(List.tabulate(length(starts grammar)+1,
           fn rule=>ItemSet.singleton(D.delay(fn()=>rule),D.delay(fn()=>0)))))
       fun update(oldSets,newSets)=
         let val holder=ref(NONE:numbered L.delay option)
             val intGotos=C.defer(fn()=>case !holder of NONE=>raise Fail"uninstalled LR0 numbering knot"
                |SOME result=>let val(_,gotos,_)=L.force result in C.drop 1 gotos end)
             val newOldSets=C.append oldSets(cZip newSets intGotos)
             val count=L.delay(fn()=>cLength newOldSets)
             val itemSets=C.append(cMap(fn(set,_)=>set)oldSets)newSets
             fun row set=
               let val closed=closure0 grammar closures set
                   val all=cMap(fn token=>(token,gotoClosure grammar closed token))tokenStream
               in C.filter(fn(_,next)=>not(ItemSet.null next))all end
             val gotos=cMap row newSets
             fun numberSets rowValue initial=
               let fun loop row state=L.delay(fn()=>
                     case L.force row of C.Nil=>
                       let val(i,gotos,found)=L.force state
                       in(i,C.cons(L.delay(fn()=>C.empty()),gotos),found)end
                      |C.Cons(value,rest)=>
                       let val(token,next)=L.force value
                           val(i,all,found)=L.force state
                           val(g,tail)=case L.force all of C.Cons(g,tail)=>(L.force g,tail)|_=>internal()
                           val existing=C.append itemSets(cReverse found)
                           val index=indexInto(L.delay(fn()=>0))next existing
                           val updated=L.delay(fn()=>case index of
                              SOME j=>(i,C.cons(L.delay(fn()=>C.cons(L.delay(fn()=>(token,j)),g)),tail),found)
                             |NONE=>(L.delay(fn()=>L.force i+1),
                                 C.cons(L.delay(fn()=>C.cons(L.delay(fn()=>(token,i)),g)),tail),
                                 C.cons(L.delay(fn()=>next),found)))
                       in L.force(loop rest updated)end)
               in loop(L.force rowValue)initial end
             val initial=L.delay(fn()=>(count,C.cons(L.delay(fn()=>C.empty()),C.empty()),C.empty()))
             val result=cFoldr numberSets initial gotos
             val _=holder:=SOME result
             val frontier=C.defer(fn()=>let val(_,_,found)=L.force result in cReverse found end)
         in(newOldSets,frontier)end
       fun done(_,newSets)_=cNull newSets
       val(old,_) =mkClosure done update(C.empty(),startRules)
   in old end
 type lr1Item=int D.t*int D.t*NameSet.set
 fun unionItems left right=C.defer(fn()=>
   case L.force right of C.Nil=>left
    |C.Cons(y,ys)=>(case L.force left of C.Nil=>right
      |C.Cons(x,xs)=>
        let val(rule,dot,la)=L.force x val(rule',dot',la')=L.force y
            val order=case Int.compare(D.force rule,D.force rule')of EQUAL=>Int.compare(D.force dot,D.force dot')|order=>order
        in case order of LESS=>C.cons(x,unionItems xs right)
         |GREATER=>C.cons(y,unionItems left ys)
         |EQUAL=>C.cons(L.delay(fn()=>(rule,dot,NameSet.union la la')),unionItems xs ys)end))
 fun subtractItem old item result=C.defer(fn()=>
   case L.force old of C.Nil=>C.cons(item,result)
    |C.Cons(value,rest)=>
      let val(rule,dot,la)=L.force value val(rule',dot',la')=L.force item
          val order=case Int.compare(D.force rule',D.force rule)of EQUAL=>Int.compare(D.force dot',D.force dot)|order=>order
      in case order of LESS=>C.cons(item,result)
       |GREATER=>subtractItem rest item result
       |EQUAL=>let val remaining=NameSet.difference la' la
                in if NameSet.null remaining then result
                   else C.cons(L.delay(fn()=>(rule,dot,remaining)),result)end end)
 fun subtractItems items old=cFoldr(fn item=>fn result=>subtractItem old item result)(C.empty())items
 fun controlFromFinite values=C.defer(fn()=>case D.force values of F.Nil=>C.empty()
   |F.Cons(value,rest)=>C.cons(L.delay(fn()=>value),controlFromFinite rest))
 fun closure1 grammar first initial=
   let val threshold=firstTerm grammar
       fun expand(rule,dot,lookahead)=C.defer(fn()=>
         let val(_,rhs,_,_)=D.force(lookupProdNo grammar(D.force rule))
         in case D.force(F.drop(D.force dot)rhs)of F.Nil=>C.empty()
          |F.Cons(symbol,beta)=>
            if D.force symbol>=3 andalso D.force symbol<threshold then
              let val terms=NameSet.fold(fn token=>fn rest=>
                       NameSet.union(first(F.append beta(singleton(D.delay(fn()=>token)))))rest)
                         NameSet.empty lookahead
                  val rules=controlFromFinite(lookupProdsOfName grammar(D.force symbol))
              in cMap(fn rule=>(rule,D.delay(fn()=>0),terms))rules end
            else C.empty()end)
       fun update(old,new)=
         let val combined=unionItems new old
             val additions=cMap expand new
             val merged=cFoldr(fn values=>fn rest=>unionItems(L.force values)rest)(C.empty())additions
         in(combined,subtractItems merged combined)end
       fun done(_,new)_=cNull new
       val(result,_)=mkClosure done update(C.empty(),initial)
   in result end
 type spontaneous=int L.delay*lr0Item*NameSet.set
 type propagation=lr0Item*int L.delay*lr0Item
 type lookaheadEntries=(lr0Item*NameSet.set)C.seq
 fun sameItem((rule,dot),(rule',dot'))=
   D.force rule=D.force rule' andalso D.force dot=D.force dot'
 fun cFlatMap f values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
   |C.Cons(value,rest)=>C.append(f(L.force value))(cFlatMap f rest))
 fun cEnumerate start values=
   let fun loop i values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
         |C.Cons(value,rest)=>C.cons(L.delay(fn()=>(i,L.force value)),loop(i+1)rest))
   in loop start values end
 fun cToList values=case L.force values of C.Nil=>[]
   |C.Cons(value,rest)=>L.force value::cToList rest
 fun controlFromItems set=
   let fun loop stream=C.defer(fn()=>case L.force stream of ItemSet.Nil=>C.empty()
         |ItemSet.Cons(item,rest)=>C.cons(L.delay(fn()=>item),loop rest))
   in loop(ItemSet.toAscList set)end
 fun lookupGoto token gotos=
   case L.force gotos of C.Nil=>NONE
    |C.Cons(value,rest)=>let val(name,index)=L.force value
       in if D.force token=D.force name then SOME index else lookupGoto token rest end
 fun containsViaList wanted set=
   let fun loop stream=case L.force stream of NameSet.Nil=>false
         |NameSet.Cons(value,rest)=>value=wanted orelse loop rest
   in loop(NameSet.toAscList set)end
 fun startLookahead grammar partial=if D.force partial then 1 else eof grammar
 fun propLookaheads grammar states first=
   let fun perState(i,(set,gotos))=
         let fun perItem original=
               let val(rule,dot)=original
                   val closed=L.delay(fn()=>closure1 grammar first
                       (C.cons(L.delay(fn()=>(rule,dot,NameSet.singleton 2)),C.empty())))
                   val values=C.defer(fn()=>L.force closed)
                   fun spontaneous(rule,dot,terms)=C.defer(fn()=>
                     case findRule grammar(D.force rule)(D.force dot)of NONE=>C.empty()
                      |SOME token=>(case lookupGoto token gotos of NONE=>raise Fail"spontaneous"
                        |SOME destination=>
                           let val realTerms=NameSet.filter(fn n=>n<>2)terms
                           in if NameSet.null realTerms then C.empty()
                              else C.cons(L.delay(fn()=>(destination,
                                   (rule,D.delay(fn()=>D.force dot+1)),realTerms)),C.empty())end))
                   fun propagated(rule,dot,terms)=C.defer(fn()=>
                     if not(containsViaList 2 terms)then C.empty()
                     else case findRule grammar(D.force rule)(D.force dot)of NONE=>C.empty()
                      |SOME token=>(case lookupGoto token gotos of NONE=>raise Fail"propagated"
                        |SOME destination=>C.cons(L.delay(fn()=>(original,destination,
                           (rule,D.delay(fn()=>D.force dot+1)))),C.empty())))
               in(cFlatMap spontaneous values,cFlatMap propagated values)end
             val perItems=cMap perItem(controlFromItems set)
             val startSpont=cMap(fn(index,start)=>
                 let val(_,_,_,partial)=D.force start
                     val terms=L.delay(fn()=>L.force(NameSet.singleton(startLookahead grammar partial)))
                 in(L.delay(fn()=>index),(D.delay(fn()=>index),D.delay(fn()=>0)),terms)end)
                 (cEnumerate 0(controlFromFinite(starts grammar)))
             val spontaneous=C.append startSpont(cFlatMap(fn(s,_)=>s)perItems)
             val propagated=cFlatMap(fn(_,p)=>p)perItems
         in(spontaneous,(i,propagated))end
       val results=cMap perState(cEnumerate 0 states)
       val spontaneous=cFlatMap(fn(s,_)=>s)results
       val propagated=A.array(0,cLength states-1)(fn()=>
          List.map(fn(_,entry)=>let val(i,p)=entry in(i,L.delay(fn()=>p))end)(cToList results))
   in(spontaneous,propagated)end
 fun foldLookahead item rest=C.defer(fn()=>
   case L.force rest of C.Nil=>C.cons(item,C.empty())
    |C.Cons(value,tail)=>
      let val(i,key,terms)=L.force item val(j,key',terms')=L.force value
      in if L.force i=L.force j andalso sameItem(key,key')then
           C.cons(L.delay(fn()=>(i,key,NameSet.union terms terms')),tail)
         else if L.force i<L.force j then C.cons(item,rest)
         else C.cons(value,foldLookahead item tail)end)
 fun addLookahead key terms entries=C.defer(fn()=>
   case L.force entries of C.Nil=>C.cons(L.delay(fn()=>(key,terms)),C.empty())
    |C.Cons(value,rest)=>let val(key',old)=L.force value
       in if sameItem(key,key')then C.cons(L.delay(fn()=>(key,NameSet.union terms old)),rest)
          else C.cons(value,addLookahead key terms rest)end)
 fun getNewPrime item old result=C.defer(fn()=>
   case L.force old of C.Nil=>C.cons(item,result)
    |C.Cons(value,rest)=>
      let val(i,key,terms)=L.force item val(key',existing)=L.force value
      in if sameItem(key,key')then
           let val delta=NameSet.filter(fn n=>not(NameSet.member n existing))terms
           in if NameSet.null delta then result
              else C.cons(L.delay(fn()=>(i,key,delta)),result)end
         else getNewPrime item rest result end)
 fun calcLookaheads nStates spontaneous propagated=
   L.delay(fn()=>
     let val work:lookaheadEntries Array.array=Array.array(nStates+1,C.empty())
         fun getNew items accum=
           case L.force items of C.Nil=>accum
            |C.Cons(item,rest)=>
              let val(i,_,_)=L.force item
                  val snapshot=Array.sub(work,L.force i)
                  val next=C.defer(fn()=>getNewPrime item snapshot accum)
              in getNew rest next end
         fun add entries=
           case L.force entries of C.Nil=>()
            |C.Cons(value,rest)=>
              let val(i,key,terms)=L.force value
                  val index=L.force i val snapshot=Array.sub(work,index)
                  val _=Array.update(work,index,addLookahead key terms snapshot)
              in add rest end
         fun propagate new=
           if cNull new then()
           else let
             fun itemTargets(j,key,terms)=
               cFlatMap(fn(source,i,target)=>
                 if sameItem(key,source)then C.cons(L.delay(fn()=>(i,target,terms)),C.empty())
                 else C.empty())(A.sub propagated(L.force j))
             val items=cFlatMap itemTargets new
             val next=getNew items(C.empty())
             val _=add new
           in propagate next end
         val initial=cFoldr foldLookahead(C.empty())spontaneous
         val _=propagate initial
         val frozen=Vector.tabulate(nStates+1,fn i=>
             let val value=Array.sub(work,i)in L.delay(fn()=>value)end)
     in A.ArrayNode(0,nStates,frozen)end)
 fun mergeLookaheadInfo lookaheads states=
   cMap(fn(index,(items,gotos))=>
     let fun intoItem(original as(rule,dot))=
           let val terms=L.delay(fn()=>
                 let fun collect values=
                       case L.force values of C.Nil=>[]
                        |C.Cons(value,rest)=>let val(key,set)=L.force value
                             in if sameItem(original,key)then set::collect rest else collect rest end
                 in case collect(A.sub lookaheads index)of []=>L.force NameSet.empty
                    |[set]=>L.force set|_=>raise Fail"mergIntoItem"end)
           in(rule,dot,terms)end
     in(cMap intoItem(controlFromItems items),gotos)end)(cEnumerate 0 states)

end
structure H=BenchHappyFn(BenchNeed)
