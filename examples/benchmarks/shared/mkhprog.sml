(* Crown Copyright 1992.
   Portable translation of N. D. North's command-line parser generator.
   The original literate source and manual carry its attribution and history. *)
functor BenchMkhprogFn(D:BENCH_SUSPEND) =
struct
  structure W=Word64
  datatype node=Nil|Cons of char*text
  withtype text=node D.t
  val empty=D.delay(fn()=>Nil)
  fun literal string=
    let val size=String.size string
        fun loop i=D.delay(fn()=>if i=size then Nil
          else Cons(String.sub(string,i),loop(i+1)))
    in loop 0 end
  fun delay make=D.delay(fn()=>D.force(make()))
  fun append first last=D.delay(fn()=>case D.force first of Nil=>D.force last
    |Cons(c,rest)=>Cons(c,append rest last))
  fun concat values=List.foldr(fn(value,rest)=>append value rest)empty values
  fun fold operation initial values=
    let fun loop total values=case D.force values of Nil=>total
          |Cons(c,rest)=>loop(operation(c,total))rest
    in loop initial values end
  fun toString values=String.implode(List.rev(fold(fn(c,cs)=>c::cs)[]values))
  fun hash values=fold(fn(c,sum)=>W.+(W.fromInt(Char.ord c),W.*(sum,0w31)))0w0 values
  fun equalConstant values pattern=
    let val size=String.size pattern
        fun loop i values=case D.force values of Nil=>i=size
          |Cons(c,rest)=>i<size andalso c=String.sub(pattern,i)andalso loop(i+1)rest
    in loop 0 values end
  fun lit body=append(literal"> ")(convert body)
  and convert body=D.delay(fn()=>case D.force body of Nil=>Nil
    |Cons(c,rest)=>if c= #"\n"then D.force(append(literal"\n> ")(convert rest))
      else Cons(c,convert rest))
  datatype target=Hashed|File of string|Usage
  type env={literate:bool,moduleName:string,target:target,emit:target*text->unit}
  type cont=env->unit
  fun stop(_:env)=()
  fun writeln body(c:cont)(env:env)=
    let val formatted=append(if #literate env then lit body else body)(literal"\n")
    in #emit env(#target env,formatted);c env end
  fun newline(c:cont)(env:env)=(#emit env(#target env,literal"\n");c env)
  fun header(c:cont)(env:env)=
    writeln(concat[literal"module ",literal(#moduleName env),
      literal" (main) where\n\nimport System (getArgs)"])c env
  fun defaultArg typ=delay(fn()=>
    if equalConstant typ "String"then literal" \"\""
    else if equalConstant typ "Bool"then literal" False"else literal" ??")
  fun defaults types c=writeln(literal"defaultArgs :: Args")
    (writeln(append(literal"defaultArgs  =  MkArgs")(concat(List.map defaultArg types)))c)
  type flag=string*text
  fun usageItem(flag,typ)=delay(fn()=>case String.explode flag of
      [#"-",c]=>if equalConstant typ "Bool"then literal(" [-"^String.str c^"]")
        else concat[literal" [",literal flag,literal" ",typ,literal"]"]
    |[#"+",c]=>literal(" [(+|-)"^String.str c^"]")
    |_=>raise Match)
  fun usage flags c=writeln(literal"usage :: IO ()")
    (writeln(concat[literal"usage  =  hPutStr stderr \"Usage: prog",
      concat(List.map usageItem flags),literal"\""])c)
  fun datadecl types c=writeln(concat[literal"data Args  =  MkArgs",
    concat(List.map(fn typ=>append(literal" ")typ)types),literal" deriving ()"])c
  fun args a b=if a>b then empty else append(literal(" x"^Int.toString a))(args(a+1)b)
  fun phead n=concat[literal"parse_args (MkArgs",args 1 n,literal") "]
  fun match sign flag=literal("('"^String.str sign^"':'"^String.str flag^"':rest)\n    =  ")
  fun wildmatch sign=literal("('"^String.str sign^"': _ :rest)\n    =  ")
  fun bits n r str=concat[literal"parse_args (MkArgs",args 1(r-1),literal" ",str,args(r+1)n,literal")) rest"]
  fun readValue n r=append(literal"readval reads (\\val -> ")(bits n r(literal"val"))
  fun readString n r=append(literal"readstring (\\str -> ")(bits n r(literal"str"))
  fun readBool n r truth=append(literal"readbool (")(bits n r(literal(if truth then"True"else"False")))
  fun oneFlag n r(flag,typ)c=case String.explode flag of
      [#"+",letter]=>writeln(concat[phead n,match #"-" letter,readBool n r false])
        (writeln(concat[phead n,match #"+" letter,readBool n r true])c)
    |[#"-",letter]=>
       let val reader=delay(fn()=>if equalConstant typ "Bool"then readBool n r true
             else if equalConstant typ "String"then readString n r else readValue n r)
       in writeln(concat[phead n,match #"-" letter,reader])c end
    |_=>raise Match
  fun parser flags c=
    let val count=List.length flags
        val finish=writeln(concat[phead count,wildmatch #"-",literal"usage"])
          (writeln(concat[phead count,literal" rest  =  prog",args 1 count,literal" (lines rest)"])c)
        fun loop _ []=finish
          |loop i(flag::rest)=oneFlag count i flag(loop(i+1)rest)
    in writeln(literal"parse_args :: Args -> String -> IO ()")(loop 1 flags)end
  val templates=BenchMkhprogTemplates.strings
  val templateTexts=List.map literal templates
  fun aux c=case templateTexts of[a,b,d,e]=>
      writeln a(newline(writeln b(newline(writeln d(newline(writeln e c))))))
    |_=>raise Fail "incorrect mkhprog templates"
  fun generate flags env=
    let val types=List.map #2 flags
        val transforms=[header,newline,defaults types,newline,usage flags,newline,
          datadecl types,newline,parser flags,newline,aux]
        val program=List.foldr(fn(make,c)=>make c)stop transforms
    in program env end
  val usageText="Usage: mkhprog [-l] [-m module_name] [-o file_name] [[-flag type] ...]"
  fun normalized input=String.concat(List.map(fn s=>s^"\n")(String.tokens Char.isSpace input))
  fun pairs values=case values of[]=>[]|[typ]=>[("",literal typ)]
    |flag::typ::rest=>(flag,literal typ)::pairs rest
  fun check flags=
    let fun valid(flag,typ)=case String.explode flag of [#"-",_]=>true
          |[#"+",_]=>equalConstant typ "Bool"|_=>false
        fun unique []=true
          |unique((flag,_)::rest)=not(List.exists(fn(other,_)=>String.sub(flag,1)=String.sub(other,1))rest)
             andalso unique rest
    in List.all valid flags andalso unique flags end
  fun lines text=String.tokens(fn c=>c= #"\n")text
  fun run input emit=
    let
      fun bad()=emit(Usage,literal usageText)
      fun readString text=
        let val start=if String.size text>0 andalso String.sub(text,0)= #"\n"then 1 else 0
            fun seek i=if i=String.size text orelse String.sub(text,i)= #"\n"then i else seek(i+1)
            val stop=seek start
            val after=if stop=String.size text then stop else stop+1
        in(String.substring(text,start,stop-start),String.extract(text,after,NONE))end
      fun parse lit moduleName channel text=
        if String.isPrefix "-l" text then
          let val rest=String.extract(text,2,NONE)
          in if rest=""then parse true moduleName channel""
             else if String.sub(rest,0)= #"\n"then parse true moduleName channel(String.extract(rest,1,NONE))
             else bad()end
        else if String.isPrefix "-m" text then
          let val(name,rest)=readString(String.extract(text,2,NONE))
          in parse lit name channel rest end
        else if String.isPrefix "-o" text then
          let val(name,rest)=readString(String.extract(text,2,NONE))
          in parse lit moduleName(File name)rest end
        else let val flags=pairs(lines text)
             in if check flags then generate flags{literate=lit,moduleName=moduleName,target=channel,emit=emit}
                else bad()end
    in parse false "Main" Hashed input end
end
