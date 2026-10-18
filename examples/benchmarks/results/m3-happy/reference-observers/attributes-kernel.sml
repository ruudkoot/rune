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

end
