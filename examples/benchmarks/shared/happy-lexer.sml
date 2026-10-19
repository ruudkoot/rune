(* Happy 1.16's continuation lexer and P result protocol. *)
functor BenchHappyLexerFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure C=BenchIdaFiniteFn(BenchNeed)
 type text=char F.seq
 type input=char C.seq
 datatype tokenId=Id|TokenType|TokenSpec|Name|Partial|Lexer|ImportedIdentity|Monad
   |Nonassoc|Left|Right|Prec|Expect|Error|AttributeType|Attribute|Code
   |Colon|SemiColon|DoubleColon|DoublePercent|Bar|Number
 datatype token=Info of text*tokenId D.t|Num of int D.t*tokenId D.t|KW of tokenId D.t|EOF
 datatype 'a result=Ok of 'a|Failed of text
 type 'a parser=input->int->'a result
 fun text s=F.fromList(String.explode s)
 fun string t=String.implode(F.toList t)
 fun input s=C.fromList(String.explode s)
 fun return value _ _=Ok value
 fun bind parser next chars line=
   case parser chars line of Ok value=>next value chars line|Failed message=>Failed message
 fun fmap f parser chars line=
   case parser chars line of Ok value=>Ok(f value)|Failed message=>Failed message
 fun fail message _ _=Failed(text message)
 fun head chars=case BenchNeed.force chars of C.Nil=>NONE
   |C.Cons(value,rest)=>SOME(BenchNeed.force value,rest)
 fun error message chars line=Failed(text(Int.toString line^": "^message^"\n"))
 fun span predicate chars=
   case head chars of NONE=>([],chars)
    |SOME(c,rest)=>if predicate c then
       let val(tail,after)=span predicate rest in(c::tail,after)end else([],chars)
 fun skip predicate chars=
   case head chars of SOME(c,rest)=>if predicate c then skip predicate rest else chars|NONE=>chars
 fun idPart c=(c>= #"a"andalso c<= #"z")orelse(c>= #"A"andalso c<= #"Z")
   orelse(c>= #"0"andalso c<= #"9")orelse c= #"_"
 fun alpha c=(c>= #"a"andalso c<= #"z")orelse(c>= #"A"andalso c<= #"Z")
 fun prefix [] chars=SOME chars
   |prefix(c::cs)chars=case head chars of SOME(d,rest)=>if c=d then prefix cs rest else NONE|NONE=>NONE
 fun quoted quote chars=
   case head chars of NONE=>([],chars)
    |SOME(c,rest)=>if c=quote then([],rest)
      else if c= #"\\"then(case head rest of NONE=>([c],rest)
             |SOME(d,after)=>let val(tail,last)=quoted quote after in(c::d::tail,last)end)
      else let val(tail,last)=quoted quote rest in(c::tail,last)end
 fun strip chars=
   let fun drop []=[]|drop(c::cs)=if Char.isSpace c then drop cs else c::cs
   in drop(List.rev(drop(List.rev chars)))end
 fun info value tag=Info(value,D.delay(fn()=>tag))
 fun keyword tag=KW(D.delay(fn()=>tag))
 fun lexNestedComment start cont chars line=
   case head chars of NONE=>error"unterminated comment"chars start
    |SOME(c,rest)=>
      (case(c,head rest)of
        (#"-",SOME(#"}",after))=>cont after line
       |(#"{",SOME(#"-",after))=>lexNestedComment line(fn tail=>fn nextLine=>
           lexNestedComment start cont tail nextLine)after line
       |(#"\n",_)=>lexNestedComment start cont rest(line+1)
       |_=>lexNestedComment start cont rest line)
 fun code cont chars depth reversed line=
   case head chars of NONE=>error"No closing '}' in code segment"chars line
    |SOME(c,rest)=>
      if c= #"\n"then code cont rest depth(c::reversed)(line+1)
      else if c= #"{"then code cont rest(depth+1)(c::reversed)line
      else if c= #"}"then if depth=0 then
        cont(info(F.defer(fn()=>F.fromList(strip(List.rev reversed))))Code)rest line
        else code cont rest(depth-1)(c::reversed)line
      else if c= #"\""then
        let val(value,after)=quoted #"\""rest
        in code cont after depth(#"\""::List.rev value@(#"\""::reversed))line end
      else if Char.isAlphaNum c then
        (case head rest of SOME(#"'",after)=>code cont after depth(#"'"::c::reversed)line
         |_=>code cont rest depth(c::reversed)line)
      else if c= #"'"then
        let val(value,after)=quoted #"'"rest
        in code cont after depth(#"'"::List.rev value@(#"'"::reversed))line end
      else code cont rest depth(c::reversed)line
 val directives=[("tokentype",TokenType),("token",TokenSpec),("name",Name),("partial",Partial),
   ("importedidentity",ImportedIdentity),("monad",Monad),("lexer",Lexer),
   ("nonassoc",Nonassoc),("left",Left),("right",Right),("prec",Prec),("expect",Expect),
   ("error",Error),("attributetype",AttributeType),("attribute",Attribute)]
 fun percent cont chars line=
   case head chars of SOME(#"%",rest)=>cont(keyword DoublePercent)rest line
    |_=>let fun choose []=
              let val(word,_)=span(fn c=>not(Char.isSpace c))chars
              in error("unrecognised directive: %"^String.implode word)chars line end
             |choose((name,tag)::rest)=
               case prefix(String.explode name)chars of SOME after=>cont(keyword tag)after line
                |NONE=>choose rest
        in choose directives end
 fun lexer cont chars line=
   case head chars of NONE=>cont EOF chars line
    |SOME(c,rest)=>
      (case(c,head rest)of
        (#"-",SOME(#"-",after))=>lexer cont(skip(fn ch=>ch<> #"\n")after)line
       |(#"{",SOME(#"-",after))=>lexNestedComment line(lexer cont)after line
       |_=>if c= #"\n"then lexer cont rest(line+1)
           else if c= #"%"then percent cont rest line
           else if c= #":"then(case head rest of SOME(#":",after)=>cont(keyword DoubleColon)after line
                                             |_=>cont(keyword Colon)rest line)
           else if c= #";"then cont(keyword SemiColon)rest line
           else if c= #"|"then cont(keyword Bar)rest line
           else if c= #"'"orelse c= #"\""then
             let val(value,after)=quoted c rest
             in cont(info(F.defer(fn()=>F.fromList(c::value@[c])))Id)after line end
           else if c= #"{"then code cont rest 0[]line
           else if Char.isSpace c then lexer cont rest line
           else if alpha c then
             let val(value,after)=span idPart rest
             in cont(info(F.defer(fn()=>F.fromList(c::value)))Id)after line end
           else if Char.isDigit c then
             let val(value,after)=span Char.isDigit rest
                 val n=D.delay(fn()=>List.foldl(fn(ch,n)=>Char.ord ch-Char.ord #"0"+10*n)0(c::value))
             in cont(Num(n,D.delay(fn()=>Number)))after line end
           else error("lexical error before "^String.str(Char.chr 96)^String.str c^"'")rest line)
end
