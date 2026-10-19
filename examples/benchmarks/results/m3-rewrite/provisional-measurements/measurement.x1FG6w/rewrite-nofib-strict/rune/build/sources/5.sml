functor BenchRewriteParserFn(E:sig
 type expr
 val variable:string->expr
 val func:string->expr BenchStream.stream->expr
end)=
struct
  structure S=BenchStream
  datatype syntax=Expr of E.expr|Items of syntax list|Text of string
  type parser=string->(syntax*string)option
  fun lift f NONE=NONE|lift f(SOME x)=SOME(f x)
  fun choice p q input=case p input of NONE=>q input|some=>some
  fun build f p input=lift(fn(value,rest)=>(f value,rest))(p input)
  fun seq2 f p q input=case p input of NONE=>NONE|SOME(x,rest)=>
    lift(fn(y,rest)=>(f x y,rest))(q rest)
  fun empty input=SOME(Items[],input)
  fun cons x(Items xs)=Items(x::xs)|cons _ _=raise Match
  fun sequence f parsers=build(fn Items xs=>f xs|_=>raise Match)
    (List.foldr(fn(p,q)=>seq2 cons p q)empty parsers)
  fun spaces parser input=
    let val n=String.size input
        fun skip i=if i<n andalso String.sub(input,i)= #" "then skip(i+1)else i
    in parser(String.extract(input,skip 0,NONE))end
  fun pchar predicate input=if String.size input=0 then NONE else
    let val c=String.sub(input,0)in if predicate c then SOME(Text(String.str c),String.extract(input,1,NONE))else NONE end
  fun look c=spaces(pchar(fn x=>x=c))
  fun stringOf predicate input=
    let val n=String.size input fun scan i=if i<n andalso predicate(String.sub(input,i))then scan(i+1)else i
        val stop=scan 0
    in if stop=0 then NONE else SOME(Text(String.substring(input,0,stop)),String.extract(input,stop,NONE))end
  fun alphanum c=(c>= #"A"andalso c<= #"Z")orelse(c>= #"a"andalso c<= #"z")orelse(c>= #"0"andalso c<= #"9")
  val identifier=spaces(stringOf alphanum)
  val operator=spaces(stringOf(fn c=>List.exists(fn x=>x=c)(String.explode"*+%@-/?:")))
  fun expression input=
    choice(sequence(fn[Expr a,Text opn,Expr b]=>Expr(E.func opn(S.fromList[a,b]))|_=>raise Match)
      [term,operator,term])term input
  and term input=
    choice(sequence(fn[Text name,_,Items args,_]=>Expr(E.func name(S.fromList(List.map(fn Expr e=>e|_=>raise Match)args)))|_=>raise Match)
      [identifier,look #"(",listOf expression #",",look #")"])primitive input
  and primitive input=choice(build(fn Text name=>
        if String.size name>0 andalso String.sub(name,0)>= #"a"andalso String.sub(name,0)<= #"z"
        then Expr(E.variable name)else Expr(E.func name(S.empty()))|_=>raise Match)identifier)
      (sequence(fn[_,e,_]=>e|_=>raise Match)[look #"(",expression,look #")"])input
  and listOf parser separator input=
    seq2 cons parser(choice(seq2(fn _=>fn y=>y)(look separator)(listOf parser separator))empty)input
  fun parse input=case expression input of SOME(Expr e,_)=>e|_=>raise Fail "invalid rewrite expression"
  fun equation input=case sequence(fn[a,_,b]=>Items[a,b]|_=>raise Match)[expression,look #"=",expression]input of
    SOME(Items[Expr a,Expr b],_)=>(a,b)|_=>raise Fail "invalid rewrite equation"
end
