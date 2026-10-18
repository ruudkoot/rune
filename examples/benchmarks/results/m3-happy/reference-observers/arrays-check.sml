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

end
structure H=BenchHappyFn(BenchNeed)
