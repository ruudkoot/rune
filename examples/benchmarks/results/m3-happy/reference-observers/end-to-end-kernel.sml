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
 val noPriority=D.delay(fn()=>No)
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
 (* Used GHC Read/Show literal operations, with Unicode escape values kept as
  * integers. Selected benchmark source text is ASCII. *)
 val asciiNames=["NUL","SOH","STX","ETX","EOT","ENQ","ACK","BEL","BS","HT","LF","VT",
   "FF","CR","SO","SI","DLE","DC1","DC2","DC3","DC4","NAK","SYN","ETB","CAN","EM",
   "SUB","ESC","FS","GS","RS","US","SP"]
 val namedEscapes=("SOH",1)::("SO",14)::
   List.filter(fn(name,_)=>name<>"SOH"andalso name<>"SO")
    (ListPair.zip(asciiNames@["DEL"],List.tabulate(33,fn i=>i)@[127]))
 fun uncons chars=case D.force chars of F.Nil=>NONE
   |F.Cons(value,rest)=>SOME(D.force value,rest)
 fun textPrefix [] chars=SOME chars
   |textPrefix(c::cs)chars=case uncons chars of
      SOME(d,rest)=>if c=d then textPrefix cs rest else NONE|NONE=>NONE
 fun dropText predicate chars=case uncons chars of
    SOME(c,rest)=>if predicate c then dropText predicate rest else chars|NONE=>chars
 fun digit base c=
   let val n=if c>= #"0"andalso c<= #"9"then Char.ord c-48
             else if c>= #"a"andalso c<= #"f"then Char.ord c-87
             else if c>= #"A"andalso c<= #"F"then Char.ord c-55 else ~1
   in if n>=0 andalso n<base then SOME n else NONE end
 fun escapeNumber base chars=
   let fun loop value count chars=case uncons chars of
          SOME(c,rest)=>(case digit base c of
             SOME n=>if value>(1114111-n)div base then NONE
               else loop(value*base+n)(count+1)rest
            |NONE=>if count=0 then NONE else SOME(value,chars))
         |NONE=>if count=0 then NONE else SOME(value,chars)
   in loop 0 0 chars end
 fun readEscape chars=
   case uncons chars of NONE=>NONE
    |SOME(c,rest)=>
      let val simple=case c of #"a"=>SOME 7| #"b"=>SOME 8| #"f"=>SOME 12| #"n"=>SOME 10
            | #"r"=>SOME 13| #"t"=>SOME 9| #"v"=>SOME 11| #"\\"=>SOME 92
            | #"\""=>SOME 34| #"'"=>SOME 39|_=>NONE
          fun named []=NONE
            |named((name,value)::names)=
               case textPrefix(String.explode name)chars of SOME after=>SOME(value,after)
                |NONE=>named names
      in case simple of SOME n=>SOME(n,rest)|NONE=>
         if c= #"x"orelse c= #"X"then escapeNumber 16 rest
         else if c= #"o"orelse c= #"O"then escapeNumber 8 rest
         else if Char.isDigit c then escapeNumber 10 chars
         else if c= #"^"then(case uncons rest of SOME(d,after)=>
              if d>= #"@"andalso d<= #"_"then SOME(Char.ord d-64,after)else NONE|NONE=>NONE)
         else named namedEscapes
      end
 fun readCharItem chars=case uncons chars of NONE=>NONE
   |SOME(#"\\",rest)=>(case readEscape rest of NONE=>NONE|SOME(n,after)=>SOME(n,true,after))
   |SOME(c,rest)=>SOME(Char.ord c,false,rest)
 fun readCharacter chars=
   case uncons chars of SOME(#"'",rest)=>
     (case readCharItem rest of SOME(n,escaped,after)=>
        if not escaped andalso n=39 then NONE
        else(case uncons after of SOME(#"'",last)=>SOME([n],last)|_=>NONE)
       |NONE=>NONE)
    |_=>NONE
 fun readString chars=
   let fun body values chars=
         case uncons chars of
          SOME(#"\\",rest)=>(case uncons rest of
            SOME(#"&",after)=>body values after
           |SOME(c,after)=>if Char.isSpace c then
              (case uncons(dropText Char.isSpace after)of SOME(#"\\",last)=>body values last|_=>NONE)
             else item values chars
           |NONE=>NONE)
         |_=>item values chars
       and item values chars=case readCharItem chars of NONE=>NONE
         |SOME(n,escaped,rest)=>if n=34 andalso not escaped then SOME(List.rev values,rest)
                              else body(n::values)rest
   in case uncons chars of SOME(#"\"",rest)=>body[]rest|_=>NONE end
 fun showEscape n next=
   if n>127 then "\\"^Int.toString n^(if next>=48 andalso next<=57 then"\\&"else"")
   else if n=127 then"\\DEL"
   else if n=92 then"\\\\"
   else if n>=32 then String.str(Char.chr n)
   else case n of 7=>"\\a"|8=>"\\b"|12=>"\\f"|10=>"\\n"|13=>"\\r"|9=>"\\t"|11=>"\\v"
       |14=>"\\SO"^(if next=72 then"\\&"else"")
       |_=>"\\"^List.nth(asciiNames,n)
 fun showCharacter[n]=if n=39 then"'\\''"else"'"^showEscape n 39^"'"
   |showCharacter _=internal()
 fun showString values=
   let fun loop [] out=String.concat(List.rev out)
         |loop(n::rest)out=
           loop rest((if n=34 then"\\\""else showEscape n(case rest of[]=>34|x::_=>x))::out)
   in "\""^loop values[]^"\""end
 (* MaybeErr control values remain memoized in both finite-data policies.
  * parE deliberately passes a poison value after failure, matching source. *)
 datatype 'a outcome=Succeeded of 'a L.delay|Rejected of text F.seq
 fun succeeded value=Succeeded(L.delay(fn()=>value))
 fun thenE outcome next=case outcome of Rejected errors=>Rejected errors|Succeeded value=>next value
 fun parE outcome next=case outcome of
    Rejected errors=>(case next(L.delay(fn()=>raise Fail"parE"))of
       Rejected more=>Rejected(F.append errors more)|Succeeded _=>Rejected errors)
   |Succeeded value=>next value
 fun parEs values=case values of []=>succeeded(F.empty())
   |value::rest=>parE value(fn first=>parE(parEs rest)(fn tail=>
      Succeeded(L.delay(fn()=>F.cons(D.delay(fn()=>L.force first),F.defer(fn()=>L.force tail))))))
 fun failMap f outcome=case outcome of Succeeded value=>Succeeded value
   |Rejected errors=>Rejected(F.map f errors)
 fun reject message=Rejected(singleton(D.delay(fn()=>X.text message)))
 fun appendText a b=F.append a b
 fun decimal n=X.text(Int.toString n)
 fun happyVar n="happy_var_"^Int.toString n
 fun readReference chars=
   let fun collect base value count chars=case uncons chars of
          SOME(c,rest)=>(case digit base c of
            SOME n=>if value>(1073741823-n)div base then NONE
                    else collect base(value*base+n)(count+1)rest
           |NONE=>if count=0 then NONE else SOME(value,chars))
         |NONE=>if count=0 then NONE else SOME(value,chars)
       fun digitsStart chars=case uncons chars of SOME(c,_)=>Char.isDigit c|NONE=>false
       fun exponentStart chars=case uncons chars of SOME(c,rest)=>
             if c= #"+"orelse c= #"-"then digitsStart rest else Char.isDigit c|NONE=>false
       fun floatingSuffix chars=case uncons chars of SOME(c,rest)=>
             if c= #"."then digitsStart rest
             else if c= #"e"orelse c= #"E"then exponentStart rest else false|NONE=>false
       fun decimal chars=case collect 10 0 0 chars of
             result as SOME(_,rest)=>if floatingSuffix rest then NONE else result|NONE=>NONE
   in case uncons chars of SOME(#"0",rest)=>
        (case uncons rest of SOME(c,after)=>
          if c= #"x"orelse c= #"X"then
            (case collect 16 0 0 after of NONE=>decimal chars|result=>result)
          else if c= #"o"orelse c= #"O"then
            (case collect 8 0 0 after of NONE=>decimal chars|result=>result)
          else decimal chars
         |NONE=>decimal chars)
      |_=>decimal chars end
 fun doCheckCode arity code=
   let fun finish acc used=
         Succeeded(L.delay(fn()=>(F.defer(fn()=>F.fromList(List.rev acc)),F.fromList used)))
       fun add output acc=List.rev(String.explode output)@acc
       fun go chars acc used=case uncons chars of NONE=>finish acc used
        |SOME(c,rest)=>
          if c= #"\""then
            (case readString chars of NONE=>go rest(c::acc)used
             |SOME(value,after)=>go after(add(showString value)acc)used)
          else if Char.isAlphaNum c then
            (case uncons rest of SOME(#"'",after)=>go after(#"'"::c::acc)used
             |_=>go rest(c::acc)used)
          else if c= #"'"then
            (case readCharacter chars of NONE=>go rest(c::acc)used
             |SOME(value,after)=>go after(add(showCharacter value)acc)used)
          else if c= #"\\"then
            (case uncons rest of SOME(#"$",after)=>go after(#"$"::acc)used
             |_=>go rest(c::acc)used)
          else if c= #"$"then
            (case uncons rest of
              SOME(#">",after)=>if arity=0 then reject"$> in empty rule"
               else go after(add(happyVar arity)acc)(arity::used)
             |SOME(n,_)=>if Char.isDigit n then
                 (case readReference rest of NONE=>raise Fail"reference integer outside recorded 31-bit domain"
                  |SOME(index,after)=>if index>arity then
                     parE(reject("$"^Int.toString index^" out of range"))(fn _=>go after acc used)
                    else go after(add(happyVar index)acc)(index::used))
                else go rest(c::acc)used
             |NONE=>go rest(c::acc)used)
          else go rest(c::acc)used
   in go code[][]end
(* Generated parser's forty source reductions. Special reductions leave the
 * semantic root delayed; generic reductions demand only their stack root. *)
 fun reduction1 stack=L.delay(fn()=>
   let val(v5,s)=pop stack val footer=get9 v5
       val(v4,s)=pop s val productions=get5 v4
       val(_,s)=pop s
       val(v2,s)=pop s val directives=get10 v2
       val(v1,s)=pop s val header=get9 v1
   in Stk(D.delay(fn()=>S4(D.delay(fn()=>AbsSyn(header,reverse directives,reverse productions,footer)))),s)end)
 fun reduction2 v2 v1=D.delay(fn()=>
   let val x=get6 v2 val xs=get5 v1 in S5(F.cons(x,xs))end)
 fun reduction3 v1=D.delay(fn()=>S5(singleton(get6 v1)))
 fun reduction4 stack=L.delay(fn()=>
   let val(v5,s)=pop stack val rules=get7 v5
       val(_,s)=pop s
       val(v3,s)=pop s val code=info X.Code v3
       val(_,s)=pop s
       val(v1,s)=pop s val name=info X.Id v1
   in Stk(D.delay(fn()=>S6(D.delay(fn()=>(name,rules,D.delay(fn()=>SOME code))))),s)end)
 fun reduction5 stack=L.delay(fn()=>
   let val(v6,s)=pop stack val rules=get7 v6
       val(_,s)=pop s val(_,s)=pop s
       val(v3,s)=pop s val code=info X.Code v3
       val(_,s)=pop s
       val(v1,s)=pop s val name=info X.Id v1
   in Stk(D.delay(fn()=>S6(D.delay(fn()=>(name,rules,D.delay(fn()=>SOME code))))),s)end)
 fun reduction6 v3 _ v1=D.delay(fn()=>
   let val rules=get7 v3 val name=info X.Id v1
   in S6(D.delay(fn()=>(name,rules,D.delay(fn()=>NONE))))end)
 fun reduction7 v3 _ v1=D.delay(fn()=>
   let val rest=get7 v3 val first=get8 v1 in S7(F.cons(first,rest))end)
 fun reduction8 v1=D.delay(fn()=>S7(singleton(get8 v1)))
 fun reduction9 stack _ chars line=
   let val(_,s)=pop stack
       val(v3,s)=pop s val code=info X.Code v3
       val(v2,s)=pop s val priority=get9 v2
       val(v1,_)=pop s val names=get15 v1
   in X.Ok(D.delay(fn()=>S8(D.delay(fn()=>(names,code,D.delay(fn()=>line),priority)))))end
 fun reduction10 stack _ chars line=
   let val(v3,s)=pop stack val code=info X.Code v3
       val(v2,s)=pop s val priority=get9 v2
       val(v1,_)=pop s val names=get15 v1
   in X.Ok(D.delay(fn()=>S8(D.delay(fn()=>(names,code,D.delay(fn()=>line),priority)))))end
 fun reduction11 v2 _=D.delay(fn()=>
   let val name=info X.Id v2 in S9(D.delay(fn()=>SOME name))end)
 val reduction12:semantic=D.delay(fn()=>S9(D.delay(fn()=>NONE)))
 fun reduction13 v2 v1=D.delay(fn()=>
   let val x=get11 v2 val xs=get10 v1 in S10(F.cons(x,xs))end)
 fun reduction14 v1=D.delay(fn()=>S10(singleton(get11 v1)))
 fun reduction15 v2 _=D.delay(fn()=>
   let val code=info X.Code v2 in S11(D.delay(fn()=>TokenType code))end)
 fun reduction16 v2 _=D.delay(fn()=>
   let val specs=get13 v2 in S11(D.delay(fn()=>TokenSpec specs))end)
 fun reduction17 v3 v2 _=D.delay(fn()=>
   let val start=get9 v3 val name=info X.Id v2
   in S11(D.delay(fn()=>TokenName(name,start,D.delay(fn()=>false))))end)
 fun reduction18 v3 v2 _=D.delay(fn()=>
   let val start=get9 v3 val name=info X.Id v2
   in S11(D.delay(fn()=>TokenName(name,start,D.delay(fn()=>true))))end)
 fun reduction19 _=D.delay(fn()=>S11(D.delay(fn()=>TokenImportedIdentity)))
 fun reduction20 v3 v2 _=D.delay(fn()=>
   let val second=info X.Code v3 val first=info X.Code v2
   in S11(D.delay(fn()=>TokenLexer(first,second)))end)
 fun reduction21 v2 _=D.delay(fn()=>
   let val monad=info X.Code v2
   in S11(D.delay(fn()=>TokenMonad(unitContext,monad,monadBind,monadReturn)))end)
 fun reduction22 v3 v2 _=D.delay(fn()=>
   let val monad=info X.Code v3 val context=info X.Code v2
   in S11(D.delay(fn()=>TokenMonad(context,monad,monadBind,monadReturn)))end)
 fun reduction23 stack=L.delay(fn()=>
   let val(v4,s)=pop stack val ret=info X.Code v4
       val(v3,s)=pop s val bind=info X.Code v3
       val(v2,s)=pop s val monad=info X.Code v2
       val(_,s)=pop s
   in Stk(D.delay(fn()=>S11(D.delay(fn()=>TokenMonad(unitContext,monad,bind,ret)))),s)end)
 fun reduction24 stack=L.delay(fn()=>
   let val(v5,s)=pop stack val ret=info X.Code v5
       val(v4,s)=pop s val bind=info X.Code v4
       val(v3,s)=pop s val monad=info X.Code v3
       val(v2,s)=pop s val context=info X.Code v2
       val(_,s)=pop s
   in Stk(D.delay(fn()=>S11(D.delay(fn()=>TokenMonad(context,monad,bind,ret)))),s)end)
 fun reduction25 v2 _=D.delay(fn()=>
   let val names=get15 v2 in S11(D.delay(fn()=>TokenNonassoc names))end)
 fun reduction26 v2 _=D.delay(fn()=>
   let val names=get15 v2 in S11(D.delay(fn()=>TokenRight names))end)
 fun reduction27 v2 _=D.delay(fn()=>
   let val names=get15 v2 in S11(D.delay(fn()=>TokenLeft names))end)
 fun reduction28 v2 _=D.delay(fn()=>
   let val count=number v2 in S11(D.delay(fn()=>TokenExpect count))end)
 fun reduction29 v2 _=D.delay(fn()=>
   let val code=info X.Code v2 in S11(D.delay(fn()=>TokenError code))end)
 fun reduction30 v2 _=D.delay(fn()=>
   let val code=info X.Code v2 in S11(D.delay(fn()=>TokenAttributetype code))end)
 fun reduction31 v3 v2 _=D.delay(fn()=>
   let val code=info X.Code v3 val name=info X.Id v2
   in S11(D.delay(fn()=>TokenAttribute(name,code)))end)
 fun reduction32 v1=D.delay(fn()=>
   let val name=info X.Id v1 in S9(D.delay(fn()=>SOME name))end)
 val reduction33:semantic=D.delay(fn()=>S9(D.delay(fn()=>NONE)))
 fun reduction34 v2 v1=D.delay(fn()=>
   let val rest=get13 v2 val first=get14 v1 in S13(F.cons(first,rest))end)
 fun reduction35 v1=D.delay(fn()=>S13(singleton(get14 v1)))
 fun reduction36 v2 v1=D.delay(fn()=>
   let val code=info X.Code v2 val name=info X.Id v1
   in S14(D.delay(fn()=>(name,code)))end)
 fun reduction37 v2 v1=D.delay(fn()=>
   let val rest=get15 v2 val first=info X.Id v1
   in S15(F.cons(D.delay(fn()=>first),rest))end)
 val reduction38:semantic=D.delay(fn()=>S15(F.empty()))
 fun reduction39 v1=D.delay(fn()=>
   let val code=info X.Code v1 in S9(D.delay(fn()=>SOME code))end)
 val reduction40:semantic=D.delay(fn()=>S9(D.delay(fn()=>NONE)))
 fun action_0 symbol=case symbol of
   33=>shift action_3
  |4=>goto action_4
  |16=>goto action_2
  |_=>reduce_40
 and action_1 symbol=case symbol of
   33=>shift action_3
  |16=>goto action_2
  |_=>failure
 and action_2 symbol=case symbol of
   18=>shift action_7
  |19=>shift action_8
  |20=>shift action_9
  |21=>shift action_10
  |22=>shift action_11
  |23=>shift action_12
  |24=>shift action_13
  |25=>shift action_14
  |26=>shift action_15
  |27=>shift action_16
  |29=>shift action_17
  |30=>shift action_18
  |31=>shift action_19
  |32=>shift action_20
  |10=>goto action_5
  |11=>goto action_6
  |_=>failure
 and action_3 symbol=case symbol of
   _=>reduce_39
 and action_4 symbol=case symbol of
   40=>accept
  |_=>failure
 and action_5 symbol=case symbol of
   18=>shift action_7
  |19=>shift action_8
  |20=>shift action_9
  |21=>shift action_10
  |22=>shift action_11
  |23=>shift action_12
  |24=>shift action_13
  |25=>shift action_14
  |26=>shift action_15
  |27=>shift action_16
  |29=>shift action_17
  |30=>shift action_18
  |31=>shift action_19
  |32=>shift action_20
  |38=>shift action_38
  |11=>goto action_37
  |_=>failure
 and action_6 symbol=case symbol of
   _=>reduce_14
 and action_7 symbol=case symbol of
   33=>shift action_36
  |_=>failure
 and action_8 symbol=case symbol of
   17=>shift action_35
  |13=>goto action_33
  |14=>goto action_34
  |_=>failure
 and action_9 symbol=case symbol of
   17=>shift action_32
  |_=>failure
 and action_10 symbol=case symbol of
   17=>shift action_31
  |_=>failure
 and action_11 symbol=case symbol of
   33=>shift action_30
  |_=>failure
 and action_12 symbol=case symbol of
   _=>reduce_19
 and action_13 symbol=case symbol of
   33=>shift action_29
  |_=>failure
 and action_14 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_28
  |_=>reduce_38
 and action_15 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_27
  |_=>reduce_38
 and action_16 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_25
  |_=>reduce_38
 and action_17 symbol=case symbol of
   34=>shift action_24
  |_=>failure
 and action_18 symbol=case symbol of
   33=>shift action_23
  |_=>failure
 and action_19 symbol=case symbol of
   17=>shift action_22
  |_=>failure
 and action_20 symbol=case symbol of
   33=>shift action_21
  |_=>failure
 and action_21 symbol=case symbol of
   _=>reduce_30
 and action_22 symbol=case symbol of
   33=>shift action_50
  |_=>failure
 and action_23 symbol=case symbol of
   _=>reduce_29
 and action_24 symbol=case symbol of
   _=>reduce_28
 and action_25 symbol=case symbol of
   _=>reduce_26
 and action_26 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_49
  |_=>reduce_38
 and action_27 symbol=case symbol of
   _=>reduce_27
 and action_28 symbol=case symbol of
   _=>reduce_25
 and action_29 symbol=case symbol of
   33=>shift action_48
  |_=>reduce_21
 and action_30 symbol=case symbol of
   33=>shift action_47
  |_=>failure
 and action_31 symbol=case symbol of
   17=>shift action_45
  |12=>goto action_46
  |_=>reduce_33
 and action_32 symbol=case symbol of
   17=>shift action_45
  |12=>goto action_44
  |_=>reduce_33
 and action_33 symbol=case symbol of
   _=>reduce_16
 and action_34 symbol=case symbol of
   17=>shift action_35
  |13=>goto action_43
  |14=>goto action_34
  |_=>reduce_35
 and action_35 symbol=case symbol of
   33=>shift action_42
  |_=>failure
 and action_36 symbol=case symbol of
   _=>reduce_15
 and action_37 symbol=case symbol of
   _=>reduce_13
 and action_38 symbol=case symbol of
   17=>shift action_41
  |5=>goto action_39
  |6=>goto action_40
  |_=>failure
 and action_39 symbol=case symbol of
   17=>shift action_41
  |33=>shift action_3
  |6=>goto action_54
  |16=>goto action_55
  |_=>reduce_40
 and action_40 symbol=case symbol of
   _=>reduce_3
 and action_41 symbol=case symbol of
   35=>shift action_52
  |37=>shift action_53
  |_=>failure
 and action_42 symbol=case symbol of
   _=>reduce_36
 and action_43 symbol=case symbol of
   _=>reduce_34
 and action_44 symbol=case symbol of
   _=>reduce_17
 and action_45 symbol=case symbol of
   _=>reduce_32
 and action_46 symbol=case symbol of
   _=>reduce_18
 and action_47 symbol=case symbol of
   _=>reduce_20
 and action_48 symbol=case symbol of
   33=>shift action_51
  |_=>reduce_22
 and action_49 symbol=case symbol of
   _=>reduce_37
 and action_50 symbol=case symbol of
   _=>reduce_31
 and action_51 symbol=case symbol of
   33=>shift action_60
  |_=>reduce_23
 and action_52 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_57
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_53 symbol=case symbol of
   33=>shift action_56
  |_=>failure
 and action_54 symbol=case symbol of
   _=>reduce_2
 and action_55 symbol=case symbol of
   _=>reduce_1
 and action_56 symbol=case symbol of
   17=>shift action_64
  |35=>shift action_65
  |_=>failure
 and action_57 symbol=case symbol of
   _=>reduce_6
 and action_58 symbol=case symbol of
   39=>shift action_63
  |_=>reduce_8
 and action_59 symbol=case symbol of
   28=>shift action_62
  |9=>goto action_61
  |_=>reduce_12
 and action_60 symbol=case symbol of
   _=>reduce_24
 and action_61 symbol=case symbol of
   33=>shift action_70
  |_=>failure
 and action_62 symbol=case symbol of
   17=>shift action_69
  |_=>failure
 and action_63 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_68
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_64 symbol=case symbol of
   35=>shift action_67
  |_=>failure
 and action_65 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_66
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_66 symbol=case symbol of
   _=>reduce_4
 and action_67 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_72
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_68 symbol=case symbol of
   _=>reduce_7
 and action_69 symbol=case symbol of
   _=>reduce_11
 and action_70 symbol=case symbol of
   36=>shift action_71
  |_=>reduce_10
 and action_71 symbol=case symbol of
   _=>reduce_9
 and action_72 symbol=case symbol of
   _=>reduce_5
 and reduce_1 j token st states stack=reduce 5 4 reduction1 j token st states stack
 and reduce_2 j token st states stack=spec2 5 reduction2 j token st states stack
 and reduce_3 j token st states stack=spec1 5 reduction3 j token st states stack
 and reduce_4 j token st states stack=reduce 5 6 reduction4 j token st states stack
 and reduce_5 j token st states stack=reduce 6 6 reduction5 j token st states stack
 and reduce_6 j token st states stack=spec3 6 reduction6 j token st states stack
 and reduce_7 j token st states stack=spec3 7 reduction7 j token st states stack
 and reduce_8 j token st states stack=spec1 7 reduction8 j token st states stack
 and reduce_9 j token st states stack=monadReduce 4 8 reduction9 j token st states stack
 and reduce_10 j token st states stack=monadReduce 3 8 reduction10 j token st states stack
 and reduce_11 j token st states stack=spec2 9 reduction11 j token st states stack
 and reduce_12 j token st states stack=spec0 9 reduction12 j token st states stack
 and reduce_13 j token st states stack=spec2 10 reduction13 j token st states stack
 and reduce_14 j token st states stack=spec1 10 reduction14 j token st states stack
 and reduce_15 j token st states stack=spec2 11 reduction15 j token st states stack
 and reduce_16 j token st states stack=spec2 11 reduction16 j token st states stack
 and reduce_17 j token st states stack=spec3 11 reduction17 j token st states stack
 and reduce_18 j token st states stack=spec3 11 reduction18 j token st states stack
 and reduce_19 j token st states stack=spec1 11 reduction19 j token st states stack
 and reduce_20 j token st states stack=spec3 11 reduction20 j token st states stack
 and reduce_21 j token st states stack=spec2 11 reduction21 j token st states stack
 and reduce_22 j token st states stack=spec3 11 reduction22 j token st states stack
 and reduce_23 j token st states stack=reduce 4 11 reduction23 j token st states stack
 and reduce_24 j token st states stack=reduce 5 11 reduction24 j token st states stack
 and reduce_25 j token st states stack=spec2 11 reduction25 j token st states stack
 and reduce_26 j token st states stack=spec2 11 reduction26 j token st states stack
 and reduce_27 j token st states stack=spec2 11 reduction27 j token st states stack
 and reduce_28 j token st states stack=spec2 11 reduction28 j token st states stack
 and reduce_29 j token st states stack=spec2 11 reduction29 j token st states stack
 and reduce_30 j token st states stack=spec2 11 reduction30 j token st states stack
 and reduce_31 j token st states stack=spec3 11 reduction31 j token st states stack
 and reduce_32 j token st states stack=spec1 12 reduction32 j token st states stack
 and reduce_33 j token st states stack=spec0 12 reduction33 j token st states stack
 and reduce_34 j token st states stack=spec2 13 reduction34 j token st states stack
 and reduce_35 j token st states stack=spec1 13 reduction35 j token st states stack
 and reduce_36 j token st states stack=spec2 14 reduction36 j token st states stack
 and reduce_37 j token st states stack=spec2 15 reduction37 j token st states stack
 and reduce_38 j token st states stack=spec0 15 reduction38 j token st states stack
 and reduce_39 j token st states stack=spec1 16 reduction39 j token st states stack
 and reduce_40 j token st states stack=spec0 16 reduction40 j token st states stack
 (* Kept in the action functions' mutual-recursion group. *)
 and newToken action states stack=
   X.lexer(fn token=>
     let fun cont i=action i i token(State action)states stack
     in case token of
        X.EOF=>cont 40
       |X.Info(_,id)=>(case D.force id of X.Id=>cont 17|X.Code=>cont 33|_=>parseError token)
       |X.Num(_,id)=>if D.force id=X.Number then cont 34 else parseError token
       |X.KW id=>(case D.force id of
          X.TokenType=>cont 18|X.TokenSpec=>cont 19|X.Name=>cont 20|X.Partial=>cont 21
         |X.Lexer=>cont 22|X.ImportedIdentity=>cont 23|X.Monad=>cont 24
         |X.Nonassoc=>cont 25|X.Left=>cont 26|X.Right=>cont 27|X.Prec=>cont 28
         |X.Expect=>cont 29|X.Error=>cont 30|X.Attribute=>cont 31|X.AttributeType=>cont 32
         |X.Colon=>cont 35|X.SemiColon=>cont 36|X.DoubleColon=>cont 37
         |X.DoublePercent=>cont 38|X.Bar=>cont 39|_=>parseError token)
     end)
 and shift action 1 token st states stack=
       let val(value,_)=pop stack
           val i=case D.force value of ErrorToken i=>i|_=>internal()
       in action i i token(State action)(pushState st states)stack end
   |shift action _ token st states stack=
       newToken action(pushState st states)(push(D.delay(fn()=>Terminal token))stack)
 and goto action j token _=action j j token(State action)
 and spec0 nt value j token st states stack=
   if j=1 then failure j token st states stack
   else let val State action=st
        in action nt j token st(pushState st states)(push value stack)end
 and spec1 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val(base,_)=popState states val State action=base
            val(v1,rest)=pop stack val value=reduce v1
        in action nt j token base states(push value rest)end
 and spec2 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val(_,states')=popState states
            val(base,_)=popState states' val State action=base
            val(v1,rest)=pop stack val(v2,rest)=pop rest val value=reduce v1 v2
        in action nt j token base states'(push value rest)end
 and spec3 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates 2 states
            val(base,_)=popState states' val State action=base
            val(v1,rest)=pop stack val(v2,rest)=pop rest val(v3,rest)=pop rest
            val value=reduce v1 v2 v3
        in action nt j token base states'(push value rest)end
 and reduce k nt fnc j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates(k-1)states
            val(base,_)=popState states' val State action=base
            val result=fnc stack val _=ignore(L.force result)
        in action nt j token base states' result end
 and monadReduce k nt fnc j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates k(pushState st states)
            val(base,_)=popState states' val State action=base
            val rest=dropStack k stack
        in X.bind(fnc stack token)(fn value=>action nt j token base states'(push value rest))end
 and accept j _ _ _ stack=
   let val(value,rest)=pop stack
       val result=if j=1 then #1(pop rest)else value
   in X.return result end
 and failure 1 token _ _ _=parseError token
   |failure i token(st as State action)states stack=
      action 1 1 token st states(push(D.delay(fn()=>ErrorToken i))stack)
 and parseError _ chars line=X.Failed(X.text(Int.toString line^": Parse error\n"))
 fun parse chars line=
   X.bind(newToken action_0
       (L.delay(fn()=>internal()):states)(L.delay(fn()=>internal()):stack))
      (fn value=>X.return(get4 value))chars line
 structure AG=
 struct
  datatype token=LBrace|RBrace|Where|Semicolon|Eq|SelfRef of text
    |SubRef of int D.t*text|RightRef of text|Unknown of text|EOF
  datatype rule=SelfAssign of text*token F.seq
    |SubAssign of(int D.t*text)*token F.seq
    |RightmostAssign of text*token F.seq
    |Conditional of token F.seq
  datatype semanticNode=Terminal of token|ErrorToken of int
    |S4 of rule F.seq|S6 of rule D.t|S7 of token F.seq
  type semantic=semanticNode D.t
  datatype stackNode=Stk of semantic*stackNode L.delay
  type stack=stackNode L.delay
  datatype state=State of int->int->token->state->statesNode L.delay->stack->text->int->semantic X.result
  and statesNode=States of state*statesNode L.delay
  type states=statesNode L.delay
  fun return value _ _=X.Ok value
  fun bind parser next chars line=
    case parser chars line of X.Ok value=>next value chars line|X.Failed error=>X.Failed error
  fun push value tail=L.delay(fn()=>Stk(value,tail))
  fun pop stack=case L.force stack of Stk(value,tail)=>(value,tail)
  fun pushState value tail=L.delay(fn()=>States(value,tail))
  fun popState stack=case L.force stack of States(value,tail)=>(value,tail)
  fun dropStack 0 stack=stack
    |dropStack n stack=let val(_,tail)=pop stack in dropStack(n-1)tail end
  fun dropStates 0 states=states
    |dropStates n states=let val(_,tail)=popState states in dropStates(n-1)tail end
  fun get4 value=case D.force value of S4 x=>x|_=>internal()
  fun get6 value=case D.force value of S6 x=>x|_=>internal()
  fun get7 value=case D.force value of S7 x=>x|_=>internal()
  fun terminal value=case D.force value of Terminal x=>x|_=>internal()
  fun selfName(SelfRef value)=value|selfName _=internal()
  fun subName(SubRef value)=value|subName _=internal()
  fun rightName(RightRef value)=value|rightName _=internal()
  fun span predicate chars=
    case uncons chars of NONE=>([],chars)
     |SOME(c,rest)=>if predicate c then
         let val(values,after)=span predicate rest in(c::values,after)end else([],chars)
  fun unknown cont chars line=
    let fun loop reversed chars=case uncons chars of NONE=>(List.rev reversed,chars)
          |SOME(#"$",rest)=>(case uncons rest of SOME(c,_)=>if c<> #"$"andalso not(Char.isDigit c)
                then loop(#"$"::reversed)rest else(List.rev reversed,chars)
             |NONE=>loop(#"$"::reversed)rest)
          |SOME(c,rest)=>if Char.isSpace c orelse List.exists(fn d=>c=d)[#"{",#"}",#";",#"="]
                  then(List.rev reversed,chars)else loop(c::reversed)rest
        val(value,rest)=loop[]chars
    in cont(Unknown(F.defer(fn()=>F.fromList value)))rest line end
  fun attribute cont build chars line=
    case uncons chars of SOME(#".",rest)=>
       (case uncons rest of SOME(c,after)=>
          if Char.isLower c then
            let val(name,tail)=span(fn c=>Char.isAlphaNum c orelse c= #"'")after
            in cont(build(F.defer(fn()=>F.fromList(c::name))))tail line end
          else X.Failed(X.text"bad attribute identifier")
        |NONE=>cont(build emptyText)chars line)
     |_=>cont(build emptyText)chars line
  fun lexer cont chars line=
    case uncons chars of NONE=>cont EOF chars line
     |SOME(c,rest)=>
       if c= #"{"then cont LBrace rest line
       else if c= #"}"then cont RBrace rest line
       else if c= #";"then cont Semicolon rest line
       else if c= #"="then cont Eq rest line
       else if c= #"w"then(case textPrefix(String.explode"where")chars of
           SOME after=>cont Where after line|NONE=>unknown cont chars line)
       else if c= #"$"then(case uncons rest of
          SOME(#"$",after)=>attribute cont SelfRef after line
         |SOME(#">",after)=>attribute cont RightRef after line
         |_=>let val(digits,after)=span Char.isDigit rest
              in if null digits then unknown cont chars line
                 else attribute cont(fn name=>SubRef(D.delay(fn()=>
                   List.foldl(fn(c,n)=>10*n+Char.ord c-48)0 digits),name))after line end)
       else if Char.isSpace c then lexer cont(dropText Char.isSpace rest)line
       else unknown cont chars line
  fun reduction1 v1=D.delay(fn()=>S4(get4 v1))
  fun reduction2 v3 _ v1=D.delay(fn()=>
    let val rest=get4 v3 val first=get6 v1 in S4(F.cons(first,rest))end)
  fun reduction3 v1=D.delay(fn()=>S4(singleton(get6 v1)))
  val reduction4:semantic=D.delay(fn()=>S4(F.empty()))
  fun reduction5 v3 _ v1=D.delay(fn()=>
    let val tokens=get7 v3 val attr=selfName(terminal v1)
    in S6(D.delay(fn()=>SelfAssign(attr,tokens)))end)
  fun reduction6 v3 _ v1=D.delay(fn()=>
    let val tokens=get7 v3 val attr=subName(terminal v1)
    in S6(D.delay(fn()=>SubAssign(attr,tokens)))end)
  fun reduction7 v3 _ v1=D.delay(fn()=>
    let val tokens=get7 v3 val attr=rightName(terminal v1)
    in S6(D.delay(fn()=>RightmostAssign(attr,tokens)))end)
  fun reduction8 v2 _=D.delay(fn()=>let val tokens=get7 v2 in S6(D.delay(fn()=>Conditional tokens))end)
  fun reduction9 stack=L.delay(fn()=>
    let val(v4,s)=pop stack val tail=get7 v4
        val(v3,s)=pop s val close=terminal v3
        val(v2,s)=pop s val body=get7 v2
        val(v1,s)=pop s val openToken=terminal v1
    in Stk(D.delay(fn()=>S7(F.append(singleton(D.delay(fn()=>openToken)))
       (F.append body(F.cons(D.delay(fn()=>close),tail))))),s)end)
  fun reduction10 v2 v1=D.delay(fn()=>
    let val tail=get7 v2 val first=terminal v1 in S7(F.cons(D.delay(fn()=>first),tail))end)
  val reduction11=reduction10
  val reduction12=reduction10
  val reduction13=reduction10
  val reduction14=reduction10
  val reduction15:semantic=D.delay(fn()=>S7(F.empty()))
  val reduction16=reduction9
  val reduction17=reduction10
  val reduction18=reduction10
  val reduction19=reduction10
  val reduction20=reduction10
  val reduction21=reduction10
  val reduction22=reduction10
  val reduction23:semantic=D.delay(fn()=>S7(F.empty()))
 fun action_0 symbol=case symbol of
   13=>shift action_4
  |14=>shift action_5
  |15=>shift action_6
  |16=>shift action_7
  |4=>goto action_8
  |5=>goto action_2
  |6=>goto action_3
  |_=>reduce_4
 and action_1 symbol=case symbol of
   13=>shift action_4
  |14=>shift action_5
  |15=>shift action_6
  |16=>shift action_7
  |5=>goto action_2
  |6=>goto action_3
  |_=>failure
 and action_2 symbol=case symbol of
   _=>reduce_1
 and action_3 symbol=case symbol of
   11=>shift action_19
  |_=>reduce_3
 and action_4 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_12
  |_=>reduce_15
 and action_5 symbol=case symbol of
   12=>shift action_11
  |_=>failure
 and action_6 symbol=case symbol of
   12=>shift action_10
  |_=>failure
 and action_7 symbol=case symbol of
   12=>shift action_9
  |_=>failure
 and action_8 symbol=case symbol of
   18=>accept
  |_=>failure
 and action_9 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_36
  |_=>reduce_15
 and action_10 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_35
  |_=>reduce_15
 and action_11 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_34
  |_=>reduce_15
 and action_12 symbol=case symbol of
   _=>reduce_8
 and action_13 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_26
  |_=>reduce_23
 and action_14 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_25
  |_=>reduce_15
 and action_15 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_24
  |_=>reduce_15
 and action_16 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_23
  |_=>reduce_15
 and action_17 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_22
  |_=>reduce_15
 and action_18 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_21
  |_=>reduce_15
 and action_19 symbol=case symbol of
   13=>shift action_4
  |14=>shift action_5
  |15=>shift action_6
  |16=>shift action_7
  |5=>goto action_20
  |6=>goto action_3
  |_=>reduce_4
 and action_20 symbol=case symbol of
   _=>reduce_2
 and action_21 symbol=case symbol of
   _=>reduce_14
 and action_22 symbol=case symbol of
   _=>reduce_13
 and action_23 symbol=case symbol of
   _=>reduce_12
 and action_24 symbol=case symbol of
   _=>reduce_11
 and action_25 symbol=case symbol of
   _=>reduce_10
 and action_26 symbol=case symbol of
   10=>shift action_44
  |_=>failure
 and action_27 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_43
  |_=>reduce_23
 and action_28 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_42
  |_=>reduce_23
 and action_29 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_41
  |_=>reduce_23
 and action_30 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_40
  |_=>reduce_23
 and action_31 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_39
  |_=>reduce_23
 and action_32 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_38
  |_=>reduce_15
 and action_33 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_37
  |_=>reduce_23
 and action_34 symbol=case symbol of
   _=>reduce_5
 and action_35 symbol=case symbol of
   _=>reduce_6
 and action_36 symbol=case symbol of
   _=>reduce_7
 and action_37 symbol=case symbol of
   _=>reduce_22
 and action_38 symbol=case symbol of
   _=>reduce_21
 and action_39 symbol=case symbol of
   _=>reduce_20
 and action_40 symbol=case symbol of
   _=>reduce_19
 and action_41 symbol=case symbol of
   _=>reduce_17
 and action_42 symbol=case symbol of
   _=>reduce_18
 and action_43 symbol=case symbol of
   10=>shift action_46
  |_=>failure
 and action_44 symbol=case symbol of
   9=>shift action_13
  |12=>shift action_14
  |14=>shift action_15
  |15=>shift action_16
  |16=>shift action_17
  |17=>shift action_18
  |7=>goto action_45
  |_=>reduce_15
 and action_45 symbol=case symbol of
   _=>reduce_9
 and action_46 symbol=case symbol of
   9=>shift action_27
  |11=>shift action_28
  |12=>shift action_29
  |14=>shift action_30
  |15=>shift action_31
  |16=>shift action_32
  |17=>shift action_33
  |8=>goto action_47
  |_=>reduce_23
 and action_47 symbol=case symbol of
   _=>reduce_16
 and reduce_1 j token st states stack=spec1 4 reduction1 j token st states stack
 and reduce_2 j token st states stack=spec3 5 reduction2 j token st states stack
 and reduce_3 j token st states stack=spec1 5 reduction3 j token st states stack
 and reduce_4 j token st states stack=spec0 5 reduction4 j token st states stack
 and reduce_5 j token st states stack=spec3 6 reduction5 j token st states stack
 and reduce_6 j token st states stack=spec3 6 reduction6 j token st states stack
 and reduce_7 j token st states stack=spec3 6 reduction7 j token st states stack
 and reduce_8 j token st states stack=spec2 6 reduction8 j token st states stack
 and reduce_9 j token st states stack=reduce 4 7 reduction9 j token st states stack
 and reduce_10 j token st states stack=spec2 7 reduction10 j token st states stack
 and reduce_11 j token st states stack=spec2 7 reduction11 j token st states stack
 and reduce_12 j token st states stack=spec2 7 reduction12 j token st states stack
 and reduce_13 j token st states stack=spec2 7 reduction13 j token st states stack
 and reduce_14 j token st states stack=spec2 7 reduction14 j token st states stack
 and reduce_15 j token st states stack=spec0 7 reduction15 j token st states stack
 and reduce_16 j token st states stack=reduce 4 8 reduction16 j token st states stack
 and reduce_17 j token st states stack=spec2 8 reduction17 j token st states stack
 and reduce_18 j token st states stack=spec2 8 reduction18 j token st states stack
 and reduce_19 j token st states stack=spec2 8 reduction19 j token st states stack
 and reduce_20 j token st states stack=spec2 8 reduction20 j token st states stack
 and reduce_21 j token st states stack=spec2 8 reduction21 j token st states stack
 and reduce_22 j token st states stack=spec2 8 reduction22 j token st states stack
 and reduce_23 j token st states stack=spec0 8 reduction23 j token st states stack
 and newToken action states stack=
   lexer(fn token=>
     let val code=case token of EOF=>18|LBrace=>9|RBrace=>10|Semicolon=>11|Eq=>12|Where=>13
            |SelfRef _=>14|SubRef _=>15|RightRef _=>16|Unknown _=>17
     in action code code token(State action)states stack end)
 and shift action 1 token st states stack=
       let val(value,_)=pop stack
           val i=case D.force value of ErrorToken i=>i|_=>internal()
       in action i i token(State action)(pushState st states)stack end
   |shift action _ token st states stack=
       newToken action(pushState st states)(push(D.delay(fn()=>Terminal token))stack)
 and goto action j token _=action j j token(State action)
 and spec0 nt value j token st states stack=
   if j=1 then failure j token st states stack
   else let val State action=st
        in action nt j token st(pushState st states)(push value stack)end
 and spec1 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val(base,_)=popState states val State action=base
            val(v1,rest)=pop stack val value=reduce v1
        in action nt j token base states(push value rest)end
 and spec2 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val(_,states')=popState states
            val(base,_)=popState states' val State action=base
            val(v1,rest)=pop stack val(v2,rest)=pop rest val value=reduce v1 v2
        in action nt j token base states'(push value rest)end
 and spec3 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates 2 states
            val(base,_)=popState states' val State action=base
            val(v1,rest)=pop stack val(v2,rest)=pop rest val(v3,rest)=pop rest
            val value=reduce v1 v2 v3
        in action nt j token base states'(push value rest)end
 and reduce k nt fnc j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates(k-1)states
            val(base,_)=popState states' val State action=base
            val result=fnc stack val _=ignore(L.force result)
        in action nt j token base states' result end
 and monadReduce k nt fnc j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates k(pushState st states)
            val(base,_)=popState states' val State action=base
            val rest=dropStack k stack
        in bind(fnc stack token)(fn value=>action nt j token base states'(push value rest))end
 and accept j _ _ _ stack=
   let val(value,rest)=pop stack
       val result=if j=1 then #1(pop rest)else value
   in return result end
 and failure 1 token _ _ _=parseError token
   |failure i token(st as State action)states stack=
      action 1 1 token st states(push(D.delay(fn()=>ErrorToken i))stack)
 and parseError _ chars line=X.Failed(X.text"Parse error\n")
 fun parse chars line=
   bind(newToken action_0
       (L.delay(fn()=>internal()):states)(L.delay(fn()=>internal()):stack))
      (fn value=>return(get4 value))chars line

 end
 fun rewriteAttributeGrammar arity lhs nonterms code attrs=
   case AG.parse code 0 of
     X.Failed message=>Rejected(singleton(D.delay(fn()=>
       F.append(X.text"error in attribute grammar rules: ")message)))
    |X.Ok rules=>
      let fun tokens rule=case rule of AG.SelfAssign(_,ts)=>ts|AG.SubAssign(_,ts)=>ts
                  |AG.RightmostAssign(_,ts)=>ts|AG.Conditional ts=>ts
          val ruleList=F.toList rules
          fun mentioned []=[]
            |mentioned(rule::rest)=
              List.map(fn AG.SubRef(n,_)=>D.force n|_=>internal())
                (List.filter(fn AG.SubRef _=>true|_=>false)(F.toList(tokens rule)))
              @mentioned rest
          fun checkArity value=if value<=arity then succeeded value
                                  else reject(Int.toString value^" out of range")
          fun afterChecks checked=
            Succeeded(L.delay(fn()=>
              let fun partition self sub conditions []=(self,sub,conditions)
                    |partition self sub conditions(rule::rest)=
                       case rule of
                         AG.SelfAssign _=>partition(rule::self)sub conditions rest
                        |AG.SubAssign _=>partition self(rule::sub)conditions rest
                        |AG.RightmostAssign(attr,ts)=>partition self
                            (AG.SubAssign((D.delay(fn()=>arity),attr),ts)::sub)conditions rest
                        |AG.Conditional _=>partition self sub(rule::conditions)rest
                  val(selfRules,subRules,conditions)=partition[][][]ruleList
                  val attributeNames=F.map(fn(name,_)=>name)attrs
                  val defaultAttribute=F.defer(fn()=>F.nth attributeNames 0)
                  val allSubProductions=L.delay(fn()=>
                    let fun loop _ []=[]
                          |loop i(name::rest)=if memberInt name nonterms then i::loop(i+1)rest
                                             else loop(i+1)rest
                    in loop 1(F.toList lhs)end)
                  fun nub values=
                    let fun loop _ []=[]
                          |loop seen(x::xs)=if List.exists(fn y=>x=y)seen then loop seen xs
                                           else x::loop(x::seen)xs
                    in loop[]values end
                  fun render()=
                    let val prods=L.force allSubProductions
                        fun has i=List.exists(fn n=>n=i)prods
                        fun attrName name=
                          case D.force name of F.Nil=>X.string defaultAttribute|_=>X.string name
                        fun formatToken token=case token of
                           AG.LBrace=>"{ "|AG.RBrace=>"} "|AG.Where=>"where "
                          |AG.Semicolon=>"; "|AG.Eq=>"="
                          |AG.SelfRef attr=>"("^attrName attr^" happySelfAttrs) "
                          |AG.RightRef attr=>formatToken(AG.SubRef(D.delay(fn()=>arity),attr))
                          |AG.SubRef(index,attr)=>
                             let val i=D.force index
                             in if has i then"("^attrName attr^" happySubAttrs_"^Int.toString i^") "
                                else(case D.force attr of F.Nil=>happyVar i^" "|_=>raise Fail"lhs ")end
                          |AG.Unknown text=>X.string text^" "
                          |AG.EOF=>internal()
                        fun formatTokens ts=String.concat(List.map formatToken(F.toList ts))
                        fun self(AG.SelfAssign(attr,ts))=attrName attr^" = "^formatTokens ts
                          |self _=internal()
                        val selfText=case selfRules of []=>""
                             |_=>"{ "^String.concatWith", "(List.map self selfRules)^" }"
                        val subMap=L.delay(fn()=>
                          let fun pair(AG.SubAssign((n,a),ts))=(D.force n,(a,ts))|pair _=internal()
                              val sorted=naturalSortBy(fn((a,_),(b,_))=>Int.compare(a,b))(List.map pair subRules)
                              fun groups []=[]
                                |groups((key,first)::rest)=
                                  let fun gather xs((n,value)::rest)=
                                           if n=key then gather(value::xs)rest else(List.rev xs,(n,value)::rest)
                                        |gather xs []=(List.rev xs,[])
                                      val(tail,rest)=gather[]rest
                                  (* Original foldr's initial head rotates first to the end. *)
                                  in(key,tail@[first])::groups rest end
                          in groups sorted end)
                        fun updates i=
                          let fun find []=[]|find((key,values)::rest)=if key=i then values else find rest
                              val values=find(L.force subMap)
                              fun item(attr,ts)=attrName attr^" = "^formatTokens ts
                          in case values of []=>""|_=>"{ "^String.concatWith", "(List.map item values)^" }"end
                        fun sub i="; (happyConditions_"^Int.toString i^",happySubAttrs_"^Int.toString i^") = "^
                             happyVar i^" happyEmptyAttrs"^updates i
                        fun condition(AG.Conditional ts)=formatTokens ts|condition _=internal()
                        val localConditions="["^String.concatWith", "(List.map condition conditions)^"]"
                        val allConditions=String.concatWith"++"(localConditions::
                            List.map(fn i=>"happyConditions_"^Int.toString i)prods)
                    in "\\happyInhAttrs -> let { happySelfAttrs = happyInhAttrs"^selfText^
                       String.concat(List.map sub prods)^"; happyConditions = "^allConditions^
                       " } in (happyConditions,happySelfAttrs)"end
                  val body=F.defer(fn()=>X.text(render()))
                  val used=F.defer(fn()=>F.fromList(nub(L.force allSubProductions@F.toList(L.force checked))))
              in(body,used)end))
      in thenE(parEs(List.map checkArity(mentioned ruleList)))afterChecks end
 val errorText=X.text"error"
 val dummyText=X.text"%dummy"
 val eofText=X.text"%eof"
 val startPrefix=X.text"%start_"
 val defaultParser=X.text"happyParse"
 val noCode=X.text"no code"
 val defaultStart=singleton(D.delay(fn()=>TokenName(defaultParser,D.delay(fn()=>NONE),D.delay(fn()=>false))))
 fun checkRules names above found=
   case D.force names of F.Nil=>Succeeded(L.delay(fn()=>reverse found))
    |F.Cons(value,rest)=>
      let val name=D.force value
      in if sameText name above then checkRules rest name found
         else if memberText name found then reject("Multiple rules for "^String.str(Char.chr 96)^X.string name^"'")
         else checkRules rest name(F.cons(value,found))end
 fun zipNames low values=
   F.defer(fn()=>case D.force values of F.Nil=>F.empty()
    |F.Cons(value,rest)=>F.cons(D.delay(fn()=>(D.delay(fn()=>low),D.force value)),zipNames(low+1)rest))
 fun codeWithAttributes arity lhs nonterms code attrs=
   case D.force attrs of F.Nil=>doCheckCode arity code
    |_=>rewriteAttributeGrammar arity lhs nonterms code attrs
 fun mangler file ast=
   let val AbsSyn(_,dirs,rules,_)=D.force ast
       fun prefix text=F.append(X.text(file^": "))text
       fun linePrefix line text=F.append(X.text(Int.toString(D.force line)^": "))text
       val names=F.map(fn(name,_,_)=>name)rules
       fun main nontermsRoot=
         let val nontermStrings=F.defer(fn()=>L.force nontermsRoot)
             val terminalStrings=F.append(flatMap(fn TokenSpec specs=>F.map(fn(name,_)=>name)specs
                                                   |_=>F.empty())dirs)(singleton(D.delay(fn()=>eofText)))
             val givenStarts=getParserNames dirs
             val startDirs=case D.force givenStarts of F.Nil=>defaultStart|_=>givenStarts
             val nStarts=length startDirs val nNonterms=length nontermStrings
             val nTerms=length terminalStrings
             val firstNt=3+nStarts val firstT=firstNt+nNonterms val lastT=firstT+nTerms-1
             val startNames=range 3(firstNt-1)
             val nontermNames=range firstNt(firstT-1)
             val terminalNames=range firstT lastT
             val startStrings=F.map(fn TokenName(name,_,_)=>F.append startPrefix name|_=>internal())startDirs
             val nameEnv=F.append(F.fromList[(D.delay(fn()=>1),errorText),(D.delay(fn()=>2),dummyText)])
               (F.append(zipNames 3 startStrings)
                (F.append(zipNames firstNt nontermStrings)(zipNames firstT terminalStrings)))
             fun lookupName value=
               F.map(fn(id,_)=>D.force id)(F.filter(fn(_,name)=>sameText name value)nameEnv)
             fun mapToName value=
               case D.force(lookupName value)of F.Nil=>
                   reject("unknown identifier "^String.str(Char.chr 96)^X.string value^"'")
                |F.Cons(id,rest)=>(case D.force rest of F.Nil=>Succeeded(L.delay(fn()=>D.force id))
                    |_=>reject("multiple use of "^String.str(Char.chr 96)^X.string value^"'"))
             fun startToken dir=case dir of TokenName(_,name,_)=>
                   (case D.force name of NONE=>succeeded firstNt|SOME value=>mapToName value)
                |_=>internal()
             fun afterStarts startTokensRoot=
               let val startTokens=F.defer(fn()=>L.force startTokensRoot)
                   val parserNames=F.map(fn TokenName(name,_,_)=>name|_=>internal())startDirs
                   val partials=F.map(fn TokenName(_,_,partial)=>D.force partial|_=>internal())startDirs
                   fun zip4 names ns tokens flags=F.defer(fn()=>
                     case(D.force names,D.force ns,D.force tokens,D.force flags)of
                       (F.Nil,F.Nil,F.Nil,F.Nil)=>F.empty()
                      |(F.Cons(a,aa),F.Cons(b,bb),F.Cons(c,cc),F.Cons(d,dd))=>
                          F.cons(D.delay(fn()=>(D.force a,b,c,d)),zip4 aa bb cc dd)
                      |_=>internal())
                   val startInfo=zip4 parserNames startNames startTokens partials
                   fun initialProds names tokens=F.defer(fn()=>
                     case(D.force names,D.force tokens)of(F.Nil,F.Nil)=>F.empty()
                      |(F.Cons(name,ns),F.Cons(token,ts))=>
                        F.cons(D.delay(fn()=>(name,singleton token,
                          D.delay(fn()=>(noCode,F.empty())),noPriority)),initialProds ns ts)
                      |_=>internal())
                   val startProds=initialProds startNames startTokens
                   val prioDirs=enumerate 1(getPrios dirs)
                   val prios=flatMap(fn(level,dir)=>flatMap(fn name=>
                       F.map(fn id=>(D.delay(fn()=>id),priorityOf(D.force level)(D.force dir)))(lookupName name))
                      (getPrioNames(D.force dir)))prioDirs
                   val prioStrings=flatMap(fn(level,dir)=>
                     F.map(fn name=>(name,priorityOf(D.force level)(D.force dir)))
                       (getPrioNames(D.force dir)))prioDirs
                   val attrs=getAttributes dirs
                   val attrType=case D.force(getAttributetype dirs)of NONE=>X.text"HappyAttrs"|SOME value=>value
                   fun convertNt(name,prods,ty)=thenE(mapToName name)(fn id=>
                      succeeded(D.delay(fn()=>L.force id),prods,ty))
                   fun mkPrec lhs prec=
                     case D.force prec of NONE=>
                       let val ts=F.filter(fn id=>memberInt id terminalNames)lhs
                           fun last values=case D.force values of F.Nil=>NONE
                             |F.Cons(value,rest)=>(case D.force rest of F.Nil=>SOME(D.force value)|_=>last rest)
                       in case last ts of NONE=>succeeded noPriority
                         |SOME name=>succeeded(case lookupInt name prios of NONE=>noPriority|SOME p=>p)end
                      |SOME name=>(case lookupText name prioStrings of NONE=>reject("Undeclared precedence token: "^X.string name)
                                  |SOME p=>succeeded p)
                   fun finishRule nt(lhs,code,line,prec)=
                     failMap(linePrefix line)
                       (parE(parEs(List.map mapToName(F.toList lhs)))(fn lhsRoot=>
                         let val numericLhs=F.defer(fn()=>L.force lhsRoot)
                         in thenE(codeWithAttributes(length lhs)numericLhs nontermNames code attrs)(fn codeRoot=>
                             thenE(mkPrec numericLhs prec)(fn p=>
                               succeeded(nt,numericLhs,D.delay(fn()=>L.force codeRoot),L.force p)))
                         end))
                   fun translateNt(nt,prods,_) =parEs(List.map(finishRule nt)(F.toList prods))
                   fun afterRules1 rules1Root=
                     let val rules1=F.defer(fn()=>L.force rules1Root)
                     in thenE(parEs(List.map translateNt(F.toList rules1)))(fn rules2Root=>
                       let val ruleGroups=F.defer(fn()=>L.force rules2Root)
                           val prods=F.append startProds(appendMany ruleGroups)
                           val prodArray=A.fromFinite(0,length prods-1)prods
                           val typed=flatMap(fn(nt,_,ty)=>
                              case D.force ty of NONE=>F.empty()
                               |SOME text=>singleton(D.delay(fn()=>(D.force nt,L.delay(fn()=>D.delay(fn()=>SOME text))))))rules1
                           val typeArray=A.accum(fn _=>fn value=>value)(L.delay(fn()=>D.delay(fn()=>NONE)))
                                  (firstNt,firstT-1)(fn()=>F.toList typed)
                           val envArray=A.array(1,lastT)(fn()=>List.map(fn(id,name)=>(D.force id,L.delay(fn()=>name)))(F.toList nameEnv))
                           fun fixSpec(name,code)=thenE(mapToName name)(fn id=>succeeded(D.delay(fn()=>L.force id),code))
                           fun finishSpecs tokenSpecsRoot=
                             let val specs=F.defer(fn()=>L.force tokenSpecsRoot)
                                 val pairs=F.map(fn(index,prod)=>
                                   let val(lhs,_,_,_)=D.force prod in(lhs,index)end)(enumerate 0 prods)
                                 val sorted=sortFinite(fn((a,_),(b,_))=>Int.compare(D.force a,D.force b))pairs
                                 fun combine values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
                                   |F.Cons(pair,rest)=>
                                     let val(key,value)=D.force pair
                                         fun gather collected rest=case D.force rest of
                                           F.Nil=>(collected,rest)
                                          |F.Cons(next,tail)=>let val(k,v)=D.force next
                                             in if D.force k=D.force key then gather(F.append collected(singleton v))tail
                                                else(collected,rest)end
                                         val(ids,tail)=gather(singleton value)rest
                                     in F.cons(D.delay(fn()=>(key,ids)),combine tail)end)
                                 val ass=combine sorted
                                 val lookupArray=A.array(3,length ass+2)(fn()=>List.map(fn(id,ids)=>
                                      (D.force id,L.delay(fn()=>ids)))(F.toList ass))
                                 fun lookupProds id=
                                   if id>=3 andalso id<firstT then A.sub lookupArray id else raise Fail"lookup_prods"
                             in succeeded(Grammar{
                               productions=prods,lookupProdNo=A.sub prodArray,lookupProdsOfName=lookupProds,
                               tokenSpecs=specs,terminals=F.cons(D.delay(fn()=>1),terminalNames),
                               nonterminals=F.append startNames nontermNames,starts=startInfo,
                               types=typeArray,tokenNames=envArray,firstNonterm=D.delay(fn()=>firstNt),
                               firstTerm=D.delay(fn()=>firstT),eof=D.delay(fn()=>lastT),priorities=prios,
                               tokenType=F.defer(fn()=>getTokenType dirs),importedIdentity=D.delay(fn()=>getImportedIdentity dirs),
                               monad=L.delay(fn()=>getMonad dirs),expect=getExpect dirs,attributes=attrs,
                               attributeType=attrType,lexer=getLexer dirs,errorHandler=getError dirs})end
                       in thenE(parEs(List.map fixSpec(F.toList(getTokenSpec dirs))))finishSpecs end)
                     end
               in thenE(parEs(List.map convertNt(F.toList rules)))afterRules1 end
         in thenE(parEs(List.map startToken(F.toList startDirs)))afterStarts end
   in failMap prefix(thenE(checkRules names emptyText(F.empty()))main)end
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
 datatype lrAction=LRShift of int D.t*priority D.t|LRReduce of int D.t*priority D.t
   |LRAccept|LRFail|LRMustFail|LRMultiple of lrAction F.seq*lrAction D.t
 datatype gotoAction=Goto of int D.t|NoGoto
 val failAction=D.delay(fn()=>LRFail)
 val acceptAction=D.delay(fn()=>LRAccept)
 val noGoto=D.delay(fn()=>NoGoto)
 fun samePriority a b=case(D.force a,D.force b)of(No,No)=>true
   |(Prio(_,n),Prio(_,m))=>D.force n=D.force m|_=>false
 fun sameAction a b=
   case(D.force a,D.force b)of
     (LRShift(n,p),LRShift(m,q))=>D.force n=D.force m andalso samePriority p q
    |(LRReduce(n,p),LRReduce(m,q))=>D.force n=D.force m andalso samePriority p q
    |(LRAccept,LRAccept)=>true|(LRFail,LRFail)=>true|(LRMustFail,LRMustFail)=>true
    |(LRMultiple(xs,x),LRMultiple(ys,y))=>sameActions xs ys andalso sameAction x y
    |_=>false
 and sameActions xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xs),F.Cons(y,ys))=>sameAction x y andalso sameActions xs ys|_=>false
 fun nubActions values=
   let fun member value []=false|member value(x::xs)=sameAction value x orelse member value xs
       fun loop values seen=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>if member value seen then loop rest seen
            else F.cons(value,loop rest(value::seen)))
   in loop values[]end
 fun resolve left right=D.delay(fn()=>
   let val a=D.force left val b=D.force right
       fun multiple loser winner=LRMultiple(singleton loser,winner)
   in case(a,b)of(LRFail,_)=>b|(_,LRFail)=>a
     |(LRMustFail,_)=>LRMustFail|(_,LRMustFail)=>LRMustFail
     |_=>if sameAction left right then a
       else case(a,b)of
          (LRAccept,_)=>LRAccept|(_,LRAccept)=>LRAccept
         |(LRMultiple(as',x),LRMultiple(bs,y))=>
            if sameAction x y then LRMultiple(nubActions(F.append as' bs),x)
            else(case D.force(resolve x y)of
              LRMultiple(cs,winner)=>
                let val losses=F.append as'(F.append bs cs)
                in if sameAction winner x then LRMultiple(nubActions(F.cons(y,losses)),x)
                   else if sameAction winner y then LRMultiple(nubActions(F.cons(x,losses)),y)
                   else raise Fail"failed invariant in resolve"end
             |other=>other)
         |(LRMultiple _,_)=>D.force(resolve left(D.delay(fn()=>LRMultiple(F.empty(),right))))
         |(_,LRMultiple _)=>D.force(resolve(D.delay(fn()=>LRMultiple(F.empty(),left)))right)
         |(LRShift _,LRReduce _)=>D.force(resolve right left)
         |(LRReduce(_,p),LRShift(_,q))=>
            (case(D.force p,D.force q)of
              (No,_)=>multiple left right|(_,No)=>multiple left right
             |(Prio(assoc,n),Prio(_,m))=>
                if D.force n<D.force m then b
                else if D.force n>D.force m then a
                else(case D.force assoc of LeftAssoc=>a|RightAssoc=>b|NonAssoc=>LRMustFail))
         |(LRReduce(r,p),LRReduce(s,q))=>
            (case(D.force p,D.force q)of
              (No,_)=>multiple left right|(_,No)=>multiple left right
             |(Prio(_,n),Prio(_,m))=>
                if D.force n<D.force m then b
                (* Preserve the source's redundant j>i guard. *)
                else if D.force m>D.force n then a
                else if D.force r<D.force s then multiple right left else multiple left right)
         |_=>raise Fail"confict in resolve"
   end)
 fun genGotoTable grammar states=L.delay(fn()=>L.force(
   let val low=firstNonterm grammar val high=firstTerm grammar-1
       fun row(_,gotos)=A.array(low,high)(fn()=>
         List.map(fn n=>(n,L.delay(fn()=>D.delay(fn()=>case lookupGoto(D.delay(fn()=>n))gotos of
              NONE=>NoGoto|SOME index=>Goto(D.delay(fn()=>L.force index))))))
           (List.filter(fn n=>n>=low andalso n<=high)(F.toList(nonterminals grammar))))
   in A.array(0,cLength states-1)(fn()=>List.map(fn(i,value)=>(i,L.delay(fn()=>row value)))
          (cToList(cEnumerate 0 states)))end))
 fun genActionTable grammar first states=L.delay(fn()=>L.force(
   let val threshold=firstTerm grammar
       val terms=terminals grammar
       val nStarts=length(starts grammar)
       val priorities=priorities grammar
       val bounds=(F.nth terms 0,F.nth terms(length terms-1))
       fun possible gotos(rule,pos,la)=C.defer(fn()=>
         case findRule grammar(D.force rule)(D.force pos)of
           SOME token=>
             if D.force token>=threshold orelse D.force token=1 then
               (case lookupGoto token gotos of NONE=>C.empty()
                 |SOME index=>
                    let val p=case lookupInt(D.force token)priorities of NONE=>noPriority|SOME p=>p
                    in C.cons(L.delay(fn()=>(token,D.delay(fn()=>LRShift(D.delay(fn()=>L.force index),p)))),C.empty())end)
             else C.empty()
          |NONE=>if D.force rule<nStarts then
              let val(_,_,_,partial)=F.nth(starts grammar)(D.force rule)
              in C.cons(L.delay(fn()=>(D.delay(fn()=>startLookahead grammar partial),acceptAction)),C.empty())end
            else let val(_,_,_,p)=D.force(lookupProdNo grammar(D.force rule))
                     fun stream values=C.defer(fn()=>case L.force values of NameSet.Nil=>C.empty()
                       |NameSet.Cons(value,rest)=>C.cons(L.delay(fn()=>
                          (D.delay(fn()=>value),D.delay(fn()=>LRReduce(rule,p)))),stream rest))
                 in stream(NameSet.toAscList la)end)
       fun row(items,gotos)=
         let val expanded=closure1 grammar first items
             val entries=cFlatMap(possible gotos)expanded
         in A.accum(fn old=>fn value=>L.delay(fn()=>resolve(L.force old)(L.force value)))
              (L.delay(fn()=>failAction))bounds(fn()=>
                List.map(fn(token,action)=>(D.force token,L.delay(fn()=>action)))(cToList entries))end
   in A.array(0,cLength states-1)(fn()=>List.map(fn(i,value)=>(i,L.delay(fn()=>row value)))
          (cToList(cEnumerate 0 states)))end))
 fun arrayElements array=
   let fun loop i high=C.defer(fn()=>if i>high then C.empty()
         else C.cons(L.delay(fn()=>A.sub array i),loop(i+1)high))
   in C.defer(fn()=>let val(low,high)=A.bounds array in loop low high end)end
 fun countConflicts action=
   let fun countOne value remaining=L.delay(fn()=>
         case D.force(L.force value)of
           LRMultiple(losers,winner)=>
             (case D.force losers of F.Nil=>raise Fail"bad conflict representation"
              |_=>let val(sr,rr)=L.force remaining
                   in case D.force winner of LRShift _=>(L.delay(fn()=>L.force sr+1),rr)
                    |LRReduce _=>(sr,L.delay(fn()=>L.force rr+1))
                    |_=>raise Fail"bad conflict representation"end)
          |_=>L.force remaining)
       fun countRow row=cFoldr countOne(L.delay(fn()=>(L.delay(fn()=>0),L.delay(fn()=>0))))(arrayElements row)
       val rows=cMap countRow(arrayElements action)
       val counts=cFoldr(fn value=>fn rest=>L.delay(fn()=>
           let val(a,b)=L.force(L.force value)val(c,d)=L.force rest
           in(L.delay(fn()=>L.force a+L.force c),L.delay(fn()=>L.force b+L.force d))end))
           (L.delay(fn()=>(L.delay(fn()=>0),L.delay(fn()=>0))))rows
       val perState=L.delay(fn()=>
         let val(low,high)=A.bounds action
             fun entries i values=case L.force values of C.Nil=>[]
               |C.Cons(value,rest)=>(i,L.delay(fn()=>L.force value))::entries(i+1)rest
             val result=A.array(low,high)(fn()=>entries low rows)
         in L.force result end)
   in(perState,counts)end
 (* ProduceCode/GenUtils ShowS builders, retaining character spines and
  * delayed right operands rather than flattening intermediate output. *)
 structure B=
 struct
   type builder=text->text
   fun id tail=tail
   fun str value tail=F.append value tail
   fun literal value=str(X.text value)
   fun cat left right tail=left(F.defer(fn()=>right tail))
   fun delayed body tail=F.defer(fn()=>body()tail)
   fun many builders tail=F.defer(fn()=>case D.force builders of F.Nil=>tail
     |F.Cons(value,rest)=>D.force value(F.defer(fn()=>many rest tail)))
   fun pieces values=many(F.fromList values)
   fun interleave separator builders tail=F.defer(fn()=>case D.force builders of F.Nil=>tail
     |F.Cons(value,rest)=>D.force value(F.append(X.text separator)(F.defer(fn()=>interleave separator rest tail))))
   fun interleave1 separator builders tail=F.defer(fn()=>case D.force builders of F.Nil=>raise Empty
     |F.Cons(value,rest)=>D.force value(F.defer(fn()=>case D.force rest of F.Nil=>tail
       |_=>F.append(X.text separator)(interleave1 separator rest tail))))
   fun bracket value=pieces[literal"(",value,literal")"]
   fun integer n=delayed(fn()=>literal(Int.toString n))
   fun output builder=builder emptyText
 end
 (* The original routine returns the first unquoted $$ substitution. *)
 fun mapDollarDollar code=
   let fun add s acc=List.rev(String.explode s)@acc
       fun go chars acc=case uncons chars of NONE=>NONE
         |SOME(c,rest)=>if c= #"\""then
            (case readString chars of NONE=>go rest(c::acc)
             |SOME(value,after)=>go after(add(showString value)acc))
          else if Char.isAlphaNum c then
            (case uncons rest of SOME(#"'",after)=>go after(#"'"::c::acc)|_=>go rest(c::acc))
          else if c= #"'"then
            (case readCharacter chars of NONE=>go rest(c::acc)
             |SOME(value,after)=>go after(add(showCharacter value)acc))
          else if c= #"\\"then
            (case uncons rest of SOME(#"$",after)=>go after(#"$"::acc)|_=>go rest(c::acc))
          else if c= #"$"then
            (case uncons rest of SOME(#"$",after)=>SOME(fn replacement=>
                 F.append(F.fromList(List.rev acc))(F.append replacement after))
              |_=>go rest(c::acc))
          else go rest(c::acc)
   in go code[]end
 fun getDefault actions=
   let fun errorAction values=case D.force values of F.Nil=>NONE
         |F.Cons(value,rest)=>let val(n,a)=D.force value
           in if n=1 then SOME a else errorAction rest end
       fun firstReduction multiple values=case D.force values of F.Nil=>NONE
         |F.Cons(value,rest)=>let val(_,a)=D.force value
           in case D.force a of LRReduce _=>if multiple then firstReduction multiple rest else SOME a
            |LRMultiple(_,winner)=>if multiple then(case D.force winner of LRReduce _=>SOME winner
                 |_=>firstReduction multiple rest)else firstReduction multiple rest
            |_=>firstReduction multiple rest end
       fun choose()=case firstReduction false actions of SOME a=>a
         |NONE=>(case firstReduction true actions of SOME a=>a|NONE=>failAction)
   in case errorAction actions of
      SOME a=>(case D.force a of LRReduce _=>a
         |LRMultiple(_,winner)=>(case D.force winner of LRReduce _=>a|_=>failAction)
         |LRFail=>choose()|_=>failAction)
     |NONE=>choose()end
 fun mkAction value=B.delayed(fn()=>case D.force value of
      LRShift(n,_)=>B.pieces[B.literal"happyShift action_",B.integer(D.force n)]
     |LRReduce(n,_)=>B.pieces[B.literal"happyReduce_",B.integer(D.force n)]
     |LRAccept=>B.literal"happyAccept"|LRFail=>B.literal"happyFail"|LRMustFail=>B.literal"happyFail"
     |LRMultiple(_,winner)=>mkAction winner)
 fun mkActionName n=B.pieces[B.literal"action_",B.integer n]
 fun mkReduceFun n=B.pieces[B.literal"happyReduce_",B.integer n]
 fun mkHappyVar n=B.pieces[B.literal"happy_var_",B.integer n]
 fun typeParam n ty=B.delayed(fn()=>case D.force ty of NONE=>B.pieces[B.literal"t",B.integer n]
   |SOME ty=>B.bracket(B.str ty))
 (* ProduceCode's TargetHaskell, coerce=False, ghc=False, strict=False
  * configuration selected by the pinned nofib Makefile. *)
 fun produceParser grammar action goto header trailer=F.defer(fn()=>
  let
   val ntTypes=types grammar
   val startsCount=L.delay(fn()=>length(starts grammar))
   val typeIndex=L.delay(fn()=>
     let val assocs=A.assocs ntTypes
         val named=F.defer(fn()=>F.map(fn(n,ty)=>case D.force ty of SOME t=>(t,n)|NONE=>internal())
                          (F.filter(fn(_,ty)=>Option.isSome(D.force ty))assocs))
         fun find text values=case D.force values of F.Nil=>raise Fail"cant find an item in list"
           |F.Cons(value,rest)=>let val(t,n)=D.force value
               in if sameText text t then n else find text rest end
     in A.array(A.bounds ntTypes)(fn()=>List.map(fn(n,ty)=>(n,L.delay(fn()=>
          case D.force ty of NONE=>n|SOME t=>find t named)))(F.toList assocs))end)
   fun absCon n=B.delayed(fn()=>B.pieces[B.literal"HappyAbsSyn",B.integer(A.sub(L.force typeIndex)n)])
   val monadInfo=L.delay(fn()=>monad grammar)
   fun usesMonad()=let val(b,_,_,_,_)=L.force monadInfo in b end
   fun context()=let val(_,a,_,_,_)=L.force monadInfo in a end
   fun tycon()=let val(_,_,a,_,_)=L.force monadInfo in a end
   fun bind()=let val(_,_,_,a,_)=L.force monadInfo in a end
   fun ret()=let val(_,_,_,_,a)=L.force monadInfo in a end
   fun fromOption value=case D.force value of NONE=>B.id|SOME t=>B.str t
   fun attrsEmpty()=case D.force(attributes grammar)of F.Nil=>true|_=>false
   val absSynDecl=B.delayed(fn()=>
     let val tyvars=F.map(fn(n,_)=>B.pieces[B.literal"t",B.integer n])
            (F.filter(fn(_,ty)=>not(Option.isSome(D.force ty)))(A.assocs ntTypes))
         val constructors=F.map(fn(n,ty)=>B.pieces[B.literal"\t| ",absCon n,B.literal" ",typeParam n ty])
            (F.filter(fn(n,_)=>A.sub(L.force typeIndex)n=n)(A.assocs ntTypes))
     in B.pieces[B.literal"data HappyAbsSyn ",
        B.delayed(fn()=>case D.force tyvars of F.Nil=>B.id|_=>B.interleave1" "tyvars),
        B.literal"\n\t= HappyTerminal ",B.str(tokenType grammar),B.literal"\n\t| HappyErrorToken Int\n",
        B.interleave"\n"constructors]end)
   val produceTypes=B.delayed(fn()=>
     if List.all(fn(_,ty)=>Option.isSome(D.force ty))(F.toList(A.assocs ntTypes))then
       let val token=B.bracket(B.str(tokenType grammar))
           val tokens=case lexer grammar of NONE=>B.pieces[B.literal"[",token,B.literal"] -> "]|SOME _=>B.id
           val result=B.literal"m HappyAbsSyn"
           val state=B.pieces[B.literal"HappyState ",token,B.literal" (HappyStk HappyAbsSyn -> ",tokens,result,B.literal")"]
           val actionNames=F.map(fn(i,_)=>mkActionName i)(A.assocs action)
           val reductionNames=F.map(fn(i,_)=>mkReduceFun(D.force i+L.force startsCount))(enumerate 0(F.drop(L.force startsCount)(productions grammar)))
           val typeSignature=B.pieces[B.literal" :: ",B.str(context()),B.literal" => Int -> HappyReduction (",B.str(tycon()),B.literal")\n\n"]
           val reductionSignature=B.pieces[B.literal" :: ",B.str(context()),B.literal" => HappyReduction (",B.str(tycon()),B.literal")\n\n"]
       in B.pieces[B.literal"type HappyReduction m = \n\t   Int \n\t-> ",token,B.literal"\n\t-> ",state,
          B.literal"\n\t-> [",state,B.literal"] \n\t-> HappyStk HappyAbsSyn \n\t-> ",tokens,result,B.literal"\n\n",
          B.interleave1",\n "actionNames,typeSignature,B.interleave1",\n "reductionNames,reductionSignature]end
     else B.id)
   fun stateFunction(state,acts)=B.delayed(fn()=>
     let val entries=A.assocs acts
         val default=L.delay(fn()=>getDefault entries)
         fun actionFunction t=B.pieces[mkActionName state,B.literal" (",B.integer t,B.literal") = "]
         fun one(t,a)=B.delayed(fn()=>case D.force a of LRFail=>B.id
           |LRReduce _=>if sameAction a(L.force default)then B.id
             else B.pieces[actionFunction t,mkAction a,B.literal"\n"]
           |_=>B.pieces[actionFunction t,mkAction a,B.literal"\n"])
         fun oneGoto(t,value)=B.delayed(fn()=>case D.force value of NoGoto=>B.id
           |Goto n=>B.pieces[actionFunction t,B.literal"happyGoto ",mkActionName(D.force n),B.literal"\n"])
     in B.pieces[B.many(F.map one entries),B.many(F.map oneGoto(A.assocs(A.sub goto state))),
          mkActionName state,B.literal" _ = ",B.delayed(fn()=>mkAction(L.force default)),B.literal"\n\n"]end)
   val produceActionTable=B.delayed(fn()=>B.many(F.map stateFunction(A.assocs action)))
   fun terminalVar n token=B.delayed(fn()=>
     case lookupInt token(tokenSpecs grammar)of NONE=>mkHappyVar n
       |SOME pattern=>(case mapDollarDollar pattern of NONE=>mkHappyVar n
          |SOME replace=>B.bracket(B.str(replace(B.output(mkHappyVar n))))))
   fun reduction(index,(nt,toks,codeCell,_))=B.delayed(fn()=>
     let val(code,used)=D.force codeCell
         val lt=length toks
         val(code',isMonad,passesToken,monadReduce)=
           case uncons code of SOME(#"%",rest)=>(case uncons rest of
              SOME(#"%",after)=>(after,true,true,"happyMonad2Reduce")
             |SOME(#"^",after)=>(after,true,true,"happyMonadReduce")
             |_ =>(rest,true,false,"happyMonadReduce"))
             |_ =>(code,false,false,"")
         val reductionFun=B.pieces[B.literal"happyReduction_",B.integer index]
         fun hdr size name=B.pieces[mkReduceFun index,B.literal" = ",B.literal name,B.literal" ",size,
             B.literal" ",B.integer(D.force nt),B.literal" ",reductionFun,B.literal"\n",reductionFun,B.literal" "]
         fun pattern(n,t)=B.delayed(fn()=>if not(memberInt n used)then B.literal"_"
            else if t>=3 andalso t<firstTerm grammar then
               B.bracket(B.pieces[absCon t,B.literal"  ",mkHappyVar n])
            else B.pieces[B.literal"(HappyTerminal ",terminalVar n t,B.literal")"])
         val patterns=reverse(F.map(fn(n,t)=>pattern(D.force n+1,D.force t))(enumerate 0 toks))
         val thisCon=absCon(D.force nt)
         val tick=String.str(Char.chr 96)
     in if isMonad andalso(usesMonad()orelse importedIdentity grammar)then
          B.pieces[hdr(B.integer lt)monadReduce,B.literal"(",B.interleave(" "^tick^"HappyStk"^tick^"\n\t")patterns,
            B.literal"happyRest) tk\n\t = happyThen (",B.bracket(B.str code'),
            if passesToken then B.literal" tk"else B.id,
            B.literal"\n\t) (\\r -> happyReturn (",thisCon,B.literal" r))"]
        else if lt<=3 then
          B.pieces[hdr B.id("happySpecReduce_"^Int.toString lt),B.interleave"\n\t"patterns,
            B.literal" =  ",thisCon,B.literal"\n\t\t (",B.str code',B.literal"\n\t)",
            if lt=0 orelse length used=0 then B.id else
             B.pieces[B.literal"\n",reductionFun,B.literal" ",
               B.interleave" "(F.map(fn _=>B.literal"_")(range 1 lt)),B.literal" = notHappyAtAll "]]
        else B.pieces[hdr(B.integer lt)"happyReduce",B.literal"(",
            B.interleave(" "^tick^"HappyStk"^tick^"\n\t")patterns,B.literal"happyRest)\n\t = ",
            thisCon,B.literal"\n\t\t (",B.str code',B.literal("\n\t) "^tick^"HappyStk"^tick^" happyRest")]
     end)
   val produceReductions=B.delayed(fn()=>B.interleave"\n\n"
      (F.map(fn(i,p)=>reduction(D.force i+L.force startsCount,D.force p))(enumerate 0(F.drop(L.force startsCount)(productions grammar)))))
   val produceTokenConverter=B.delayed(fn()=>
     let val eofTok=B.integer(eof grammar)
         fun eofAction tk=B.pieces[B.literal"action ",eofTok,B.literal" ",eofTok,B.literal(" "^tk^" (HappyState action) sts stk")]
         val doAction=B.literal"action i i tk (HappyState action)"
         fun doToken(i,pattern)=B.delayed(fn()=>
           let val p=case mapDollarDollar pattern of NONE=>pattern|SOME replace=>replace(X.text"happy_dollar_dollar")
           in B.pieces[B.str p,B.literal" -> cont ",B.integer(D.force i)]end)
         val tokens=B.interleave";\n\t"(F.map doToken(tokenSpecs grammar))
     in case lexer grammar of NONE=>B.pieces[
          B.literal"happyNewToken action sts stk [] =\n\t",eofAction"notHappyAtAll",B.literal" []\n\n",
          B.literal"happyNewToken action sts stk (tk:tks) =\n\tlet cont i = ",doAction,
          B.literal" sts stk tks in\n\tcase tk of {\n\t",tokens,
          B.literal"_ -> happyError' (tk:tks)\n\t}\n\nhappyError_ tk tks = happyError' (tk:tks)\n"]
       |SOME(lex,endToken)=>B.pieces[B.literal"happyNewToken action sts stk\n\t= ",B.str lex,
          B.literal"(\\tk -> \n\tlet cont i = ",doAction,B.literal" sts stk in\n\tcase tk of {\n\t",
          B.str endToken,B.literal" -> ",eofAction"tk",B.literal";\n\t",tokens,
          B.literal"_ -> happyError' tk\n\t})\n\nhappyError_ tk = happyError' tk\n"]end)
   val identityStuff=B.delayed(fn()=>if usesMonad()then B.id
     else if importedIdentity grammar then B.literal"type HappyIdentity = Identity\nhappyIdentity = Identity\nhappyRunIdentity = runIdentity\n\n"
     else B.literal"newtype HappyIdentity a = HappyIdentity a\nhappyIdentity = HappyIdentity\nhappyRunIdentity (HappyIdentity a) = a\n\ninstance Monad HappyIdentity where\n    return = HappyIdentity\n    (HappyIdentity p) >>= q = q p\n\n")
   val monadStuff=B.delayed(fn()=>
     let val ctx=B.str(context())val ty=B.str(tycon())
         val handler=case errorHandler grammar of SOME h=>B.str h
           |NONE=>(case lexer grammar of NONE=>B.literal"happyError"|SOME _=>B.literal"(\\token -> happyError)")
     in B.pieces[B.literal"happyThen :: ",ctx,B.literal" => ",ty,B.literal" a -> (a -> ",ty,B.literal" b) -> ",ty,
        B.literal" b\nhappyThen = ",B.bracket(B.str(bind())),B.literal"\nhappyReturn :: ",ctx,B.literal" => a -> ",ty,
        B.literal" a\nhappyReturn = ",B.bracket(B.str(ret())),B.literal"\n",
        case lexer grammar of NONE=>B.pieces[
          B.literal"happyThen1 m k tks = (",B.str(bind()),B.literal") m (\\a -> k a tks)\nhappyReturn1 :: ",ctx,
          B.literal" => a -> b -> ",ty,B.literal" a\nhappyReturn1 = \\a tks -> ",B.bracket(B.str(ret())),
          B.literal" a\nhappyError' :: ",ctx,B.literal" => [",B.str(tokenType grammar),B.literal"] -> ",ty,
          B.literal" a\nhappyError' = ",if usesMonad()then B.id else B.literal"HappyIdentity . ",handler,B.literal"\n\n"]
        |SOME _=>B.pieces[B.literal"happyThen1 = happyThen\nhappyReturn1 :: ",ctx,B.literal" => a -> ",ty,
          B.literal" a\nhappyReturn1 = happyReturn\nhappyError' :: ",ctx,B.literal" => ",B.str(tokenType grammar),
          B.literal" -> ",ty,B.literal" a\nhappyError' tk = ",if usesMonad()then B.id else B.literal"HappyIdentity ",
          handler,B.literal" tk\n\n"]]end)
   fun entry(no,(name,_,acceptNt,_))=B.delayed(fn()=>
     let val tks=case lexer grammar of NONE=>B.literal" tks"|SOME _=>B.id
     in B.pieces[if attrsEmpty()then B.str name else B.pieces[B.literal"do_",B.str name],tks,
        B.literal" = ",if usesMonad()then B.id else B.literal"happyRunIdentity ",
        B.literal"happySomeParser where\n  happySomeParser = happyThen (happyParse ",mkActionName no,tks,
        B.literal") ",B.bracket(B.pieces[B.literal"\\x -> case x of {HappyAbsSyn",
          B.integer(A.sub(L.force typeIndex)(D.force acceptNt)),B.literal" z -> happyReturn z; _other -> notHappyAtAll }"])]end)
   val attrEntries=B.delayed(fn()=>if attrsEmpty()then B.id else
     let val(default,_) =F.nth(attributes grammar)0
         fun one(name,_,_,_)=B.delayed(fn()=>
           if usesMonad()then B.pieces[B.str name,
             (case lexer grammar of NONE=>B.literal" toks = do { f <- do_"|SOME _=>B.literal" = do { f <- do_"),
             B.str name,(case lexer grammar of NONE=>B.literal" toks; "|SOME _=>B.literal"; "),
             B.literal"let { (conds,attrs) = f happyEmptyAttrs } in do { sequence_ conds; return (",
             B.str default,B.literal" attrs) }}"]
           else case lexer grammar of SOME _=>raise Fail"attribute grammars not supported for non-monadic parsers with %lexer"
             |NONE=>B.pieces[B.str name,B.literal" toks = let { f = do_",B.str name,
               B.literal" toks; (conds,attrs) = f happyEmptyAttrs; x = foldr seq attrs conds; } in (",B.str default,B.literal" x)"])
     in B.interleave"\n\n"(F.map one(starts grammar))end)
   val produceEntries=B.pieces[B.delayed(fn()=>B.interleave"\n\n"(F.map(fn(i,value)=>entry(D.force i,D.force value))(enumerate 0(starts grammar)))),attrEntries]
   val produceAttributes=B.delayed(fn()=>if attrsEmpty()then B.id else
     let val attrs=attributes grammar
         val attrType=case D.force(attributeType grammar)of F.Nil=>X.text"HappyAttributes"|_=>attributeType grammar
         fun field(name,ty)=B.pieces[B.str name,B.literal" :: ",B.str ty]
         fun bad(name,_)=B.pieces[B.str name,B.literal" = error \"invalid reference to attribute '",B.str name,B.literal"'\""]
     in B.pieces[B.literal"data ",B.str attrType,B.literal" = HappyAttributes {",B.interleave1", "(F.map field attrs),
          B.literal"}\nhappyEmptyAttrs = HappyAttributes {",B.interleave1", "(F.map bad attrs),B.literal"}\n"]end)
  in B.output(B.pieces[fromOption header,B.literal"\n-- parser produced by Happy Version 1.16\n\n",
      absSynDecl,B.literal"\n",produceTypes,produceActionTable,produceReductions,produceTokenConverter,B.literal"\n",
      identityStuff,monadStuff,produceEntries,B.literal"happySeq = happyDontSeq\n\n",produceAttributes,
      B.literal"\n",fromOption trailer,B.literal"\n"])
  end)
 (* Main's selected non-GLR redundancy analysis retains linear nub/member
  * searches; generated token/production arrays are shared with codegen. *)
 fun firstReduction action=F.defer(fn()=>case D.force action of
      LRReduce(rule,_)=>singleton rule
     |LRMultiple(_,winner)=>firstReduction winner|_=>F.empty())
 fun isShift action=case D.force action of LRShift _=>true
   |LRMultiple(_,winner)=>(case D.force winner of LRShift _=>true|_=>false)|_=>false
 fun nubInts values=
   let fun go seen values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>if List.exists(fn x=>x=D.force value)seen then go seen rest
            else F.cons(value,go(D.force value::seen)rest))
   in go[]values end
 fun findRedundancies grammar action=
   let val actions=flatMap(fn(_,row)=>A.assocs row)(A.assocs action)
       val usedRules=F.append(range 0(length(starts grammar)-1))
           (nubInts(flatMap(fn(_,a)=>firstReduction a)actions))
       val usedTokens=F.cons(D.delay(fn()=>1),F.cons(D.delay(fn()=>eof grammar),
           nubInts(F.map(fn(n,_)=>n)(F.filter(fn(_,a)=>isShift a)actions))))
       val unusedRules=F.filter(fn r=>not(memberInt r usedRules))(range 0(length(productions grammar)-1))
       val unusedTokens=F.filter(fn n=>not(memberInt n usedTokens))(terminals grammar)
   in(unusedRules,F.map(fn n=>A.sub(tokenNames grammar)n)unusedTokens)end
 fun generate input=
   let val ast=case parse(X.input input)1 of X.Failed message=>raise Fail(String.implode(F.toList message))
         |X.Ok ast=>ast
       val grammar=case mangler"TestInput.y"ast of Succeeded value=>L.force value
         |Rejected errors=>raise Fail(String.implode(F.toList(flatMap(fn x=>F.append x(X.text"\n"))errors)))
       val AbsSyn(hd,_,_,tl)=D.force ast
       val first=mkFirst grammar
       val states=genLR0items grammar(precalcClosure0 grammar)
       val(spont,prop)=propLookaheads grammar states first
       val final=calcLookaheads(cLength states)spont prop
       val merged=mergeLookaheadInfo final states
       val goto=genGotoTable grammar states
       val action=genActionTable grammar first merged
       val(_,counts)=countConflicts action
       val(unusedRules,unusedTokens)=findRedundancies grammar action
       val warnings=F.defer(fn()=>
         let fun unused label values=case D.force values of F.Nil=>emptyText
               |_=>X.text("unused "^label^": "^Int.toString(length values)^"\n")
             fun conflicts()=
               let val(sr,rr)=L.force counts
                   val sr=L.force sr val rr=L.force rr
               in case expect grammar of SOME n=>
                 if n=sr andalso rr=0 then emptyText
                 else if rr>0 then raise Fail("The grammar has reduce/reduce conflicts.\n"^
                   "This is not allowed when an expect directive is given\n")
                 else raise Fail("The grammar has "^Int.toString sr^" shift/reduce conflicts.\n"^
                   "This is different from the number given in the expect directive\n")
               |NONE=>X.text((if sr=0 then""else"shift/reduce conflicts:  "^Int.toString sr^"\n")^
                            (if rr=0 then""else"reduce/reduce conflicts: "^Int.toString rr^"\n"))end
         in F.append(unused"rules"unusedRules)
             (F.defer(fn()=>F.append(unused"terminals"unusedTokens)(F.defer conflicts)))end)
       val header=D.delay(fn()=>SOME(F.append(case D.force hd of NONE=>emptyText|SOME t=>t)(X.text"\n")))
   in(warnings,produceParser grammar action goto header tl)end
 fun emitOutput input emitWarning emitBody=
   let val(warnings,body)=generate input
       fun stream emit text=case D.force text of F.Nil=>()
         |F.Cons(value,rest)=>(emit(D.force value);stream emit rest)
   in stream emitWarning warnings;stream emitBody body end

end
