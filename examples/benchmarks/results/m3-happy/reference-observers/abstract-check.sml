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
 fun getTokenType dirs=exactly"token type given"(select(fn TokenType t=>SOME t|_=>NONE)dirs)
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

end
structure H=BenchHappyFn(BenchNeed)
