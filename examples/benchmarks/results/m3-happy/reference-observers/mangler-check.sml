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
fun rewriteAttributeGrammar arity lhs nonterms code attrs=raise Fail"attribute grammar port pending"
 val errorText=X.text"error"
 val dummyText=X.text"%dummy"
 val eofText=X.text"%eof"
 val startPrefix=X.text"%start_"
 val emptyText=X.text""
 val defaultParser=X.text"happyParse"
 val noCode=X.text"no code"
 val noPriority= D.delay(fn()=>No)
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

end
structure H=BenchHappyFn(BenchNeed)
