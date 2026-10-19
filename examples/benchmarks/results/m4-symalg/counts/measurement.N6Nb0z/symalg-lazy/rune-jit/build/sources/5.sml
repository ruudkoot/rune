(* Source lexer, precedence parser, environment, evaluator and printer.
 * AST nodes and evaluated numeric payloads follow D; token descriptors and
 * finite binding/argument list spines are strict portable metadata. *)
functor BenchSymalgFn(D:BENCH_SUSPEND)=
struct
 structure B=BenchSymalgNumberFn(D)
 structure Z=IntInf
 structure L=BenchLazy
 datatype expressionNode=Func of string*expressionNode D.t list
   |Numb of B.number D.t|Var of string|EVar of string|BSError
 type expression=expressionNode D.t
 datatype command=Set of string*expression|EvalSet of string*expression
   |Eval of expression|NullCmd|SyntaxError
 datatype token=Ide of string|Evar of string|Op of string|Num of string|Lparen|Rparen|Comma
 fun func name args=D.delay(fn()=>Func(name,args))
 fun numb f=D.delay(fn()=>Numb(D.delay f))
 fun error()=D.delay(fn()=>BSError)
 fun opPrec text=case text of"=="=>5|">="=>5|"<="=>5|"/="=>5|">"=>5|"<"=>5
   |"+"=>4|"-"=>4|"*"=>3|"/"=>3|"^"=>2|_=>0
 fun opPrec1"-"=1|opPrec1 _=0
 fun opName text=case text of"=="=>"equ"|">="=>"gte"|"<="=>"lte"|"/="=>"ne"|">"=>"gt"|"<"=>"lt"
   |"+"=>"add"|"-"=>"sub"|"*"=>"mul"|"/"=>"div"|"^"=>"pow"|_=>""
 fun opName1"-"="neg"|opName1 _=""
 fun opAssoc text=if List.exists(fn x=>x=text)["==",">=","<=","/=",">","<"]then"non"
   else if List.exists(fn x=>x=text)["+","-","*","/"]then"left"else if text="^"then"right"else"non"
 fun toOp text=case text of"equ"=>"=="|"gte"=>">="|"lte"=>"<="|"ne"=>"/="|"gt"=>">"|"lt"=>"<"
   |"add"=>"+"|"sub"=>"-"|"mul"=>"*"|"div"=>"/"|"pow"=>"^"|_=>""
 fun toOp1"neg"="-"|toOp1 _=""
 fun span test chars=
   let fun loop [] out=(String.implode(List.rev out),[])
         |loop(all as c::rest)out=if test c then loop rest(c::out)else(String.implode(List.rev out),all)
   in loop chars[]end
 fun lexer text=
   let fun scan []=([],true)
         |scan(all as c::rest)=
          if Char.isSpace c then scan rest
          else if Char.isAlpha c then let val(a,b)=span Char.isAlphaNum all in emit(Ide a)b end
          else if Char.isDigit c then
            let val(a,b)=span Char.isDigit all
                val(fraction,last)=case b of #"."::tail=>let val(d,r)=span Char.isDigit tail in("."^d,r)end|_=>( "",b)
            in emit(Num(a^fraction))last end
          else if Char.contains"+-*/^='><"c then
            let val(operation,last)=
                  if Char.contains"+-*^"c then(String.str c,rest)
                  else case rest of #"="::tail=>
                    if Char.contains"=></"c then(String.str c^"=",tail)else(String.str c,rest)
                    |_ =>(String.str c,rest)
            in emit(Op operation)last end
          else if c= #"("then emit Lparen rest
          else if c= #")"then emit Rparen rest
          else if c= #","then emit Comma rest
          else if c= #"$"then let val(a,b)=span Char.isAlphaNum rest in emit(Evar("$"^a))b end
          else([],false)
       and emit token rest=let val(tokens,success)=scan rest in(token::tokens,success)end
   in scan(String.explode text)end
 fun parseBexpr []=(error(),[])
   |parseBexpr tokens=parsePrec 7 tokens
 and parsePrec prec rest=
   if prec=0 then parseAtomic rest
   else case rest of Op operation::tail=>
      if opName1 operation=""then(error(),rest)
      else let val(t,r)=parsePrec(opPrec1 operation-1)tail
           in parseAccum prec(func(opName1 operation)[t])r end
    |_=>let val(t,r)=parsePrec(prec-1)rest in parseAccum prec t r end
 and parseAccum prec sofar rest=case rest of Op operation::tail=>
     if prec>=opPrec operation then
       let val(t,r)=parseOp operation sofar tail in parseAccum prec t r end
     else(sofar,rest)
   |_ =>(sofar,rest)
 and parseOp operation sofar rest=
   if opName operation=""then(error(),rest)
   else if opAssoc operation="right"then
     let val(t,r)=parsePrec(opPrec operation)rest in(func(opName operation)[sofar,t],r)end
   else if opAssoc operation="left"then parseLeft operation sofar rest
   else let val(t,r)=parsePrec(opPrec operation-1)rest in(func(opName operation)[sofar,t],r)end
 and parseLeft operation sofar rest=
   let val(t,r)=parsePrec(opPrec operation-1)rest
       val next=func(opName operation)[sofar,t]
   in case r of Op more::tail=>if opPrec operation=opPrec more then parseLeft more next tail else(next,r)
      |_ =>(next,r)end
 and parseAtomic(Evar name::rest)=(D.delay(fn()=>EVar name),rest)
   |parseAtomic(Ide name::Lparen::rest)=
      let val(args,r,success)=parseArgs[]rest
      in(if success then func name args else error(),r)end
   |parseAtomic(Ide name::rest)=(D.delay(fn()=>Var name),rest)
   |parseAtomic(Num text::rest)=(numb(fn()=>B.decimal text),rest)
   |parseAtomic(Lparen::rest)=let val(t,r)=parseBexpr rest
       in case r of Rparen::tail=>(t,tail)|_=>(error(),r)end
   |parseAtomic tokens=(error(),tokens)
 and parseArgs accum(Rparen::rest)=(accum,rest,true)
   |parseArgs accum tokens=
      let val(arg,rest)=parseBexpr tokens
      in case rest of Comma::tail=>parseArgs(accum@[arg])tail
          |Rparen::tail=>(accum@[arg],tail,true)|_=>([],[],false)end
 fun parseCommand []=(NullCmd,[])
   |parseCommand(Evar name::Op"="::rest)=
      (case rest of []=>(NullCmd,[])
       |Op"'"::tail=>let val(t,r)=parseBexpr tail in(Set(name,t),r)end
       |_=>let val(t,r)=parseBexpr rest in(EvalSet(name,t),r)end)
   |parseCommand tokens=let val(t,r)=parseBexpr tokens in(Eval t,r)end
 fun parse text=let val(tokens,success)=lexer text
   in if not success then SyntaxError
      else let val(command,rest)=parseCommand tokens in if List.null rest then command else SyntaxError end end
 fun initial()=[("$prec",numb(fn()=>B.Integer 20))]
 fun lookup name []=error()
   |lookup name((key,value)::rest)=if name=key then value else lookup name rest
 fun enter name value env=(name,value)::List.filter(fn(key,_)=>key<>name)env
 fun precision env=
   let val value=eval(lookup"$prec"env)env
       val number=case D.force value of Numb n=>B.subtract(B.Integer 0)(D.force n)|_=>B.Integer(~10)
       val text=B.format number(~10)
       val digits=if String.isPrefix"-"text orelse String.isPrefix"~"text then String.extract(text,1,NONE)else text
       val _=if String.size digits>0 andalso List.all Char.isDigit(String.explode digits)then()
             else raise Fail"invalid source precision"
   in case Z.fromString text of SOME n=>n|NONE=>raise Fail"invalid source precision"end
 and eval expression env=D.delay(fn()=>case D.force expression of
     EVar name=>D.force(eval(lookup name env)env)
    |Func(name,args)=>
       let val nargs=List.map(fn x=>eval x env)args
       in case nargs of []=>Func(name,[])
          |[arg]=>if List.exists(fn x=>x=name)["sqrt","real","rat","neg"]then
             (case D.force arg of Numb value=>Numb(D.delay(fn()=>
               let val n=D.force value in case name of
                 "sqrt"=>B.squareRoot n|"real"=>B.makeReal n
                |"rat"=>B.rationalAt n(precision env)|_=>B.subtract(B.Integer 0)n end))
              |_=>Func(name,[arg]))
             else Func(name,[arg])
          |[a,b]=>if List.exists(fn x=>x=name)["add","sub","mul","div","equ","ne","gte","lte","lt","gt"]then
             (case(D.force a,D.force b)of(Numb x,Numb y)=>Numb(D.delay(fn()=>
               let val xx=D.force x val yy=D.force y
                   fun boolean f=B.Integer(if f xx yy(precision env)then 1 else 0)
               in case name of"add"=>B.add xx yy|"sub"=>B.subtract xx yy
                 |"mul"=>B.multiply xx yy|"div"=>B.divide xx yy
                 |"equ"=>boolean B.equal|"ne"=>boolean B.notEqual
                 |"gte"=>boolean B.greaterEqual|"lte"=>boolean B.lessEqual
                 |"lt"=>boolean B.less|_=>boolean B.greater end))
              |_=>Func(name,[a,b]))
             else Func(name,[a,b])
          |_=>Func(name,nargs)end
    |other=>other)
 structure W=Word64
 val modulus=valOf(Z.fromString"18446744073709551616")
 fun hash text=
   let val value=List.foldl(fn(c,h)=>W.+(W.fromInt(Char.ord c),W.*(h,0w31)))0w0(String.explode text)
       val n=W.toLargeInt value
   in B.decimalInteger(if W.andb(value,0wx8000000000000000)=0w0 then n else n-modulus)end
 val numberObserver=ref(fn(_:string)=>())
 fun numberString(B.Rational(a,b))_=
     let val text=if a=0 then"0"else if b=1 then B.decimalInteger a
                  else"("^B.format(B.Rational(a,b))0^")"
         val _=(!numberObserver)text
     in text end
   |numberString n prec=
     let val text=B.format n prec val _=(!numberObserver)text
     in hash text end
 fun printExp p expression env=case D.force expression of
     Func(name,args)=>
      let val operation=case args of[_,_]=>toOp name|[_]=>toOp1 name|_=>""
      in if operation=""then name^"("^String.concatWith","(List.map(fn x=>printExp 10 x env)args)^")"
         else case args of [arg]=>
           let val mp=opPrec1 operation val result=operation^printExp mp arg env
           in if mp>p then"("^result^")"else result end
          |[a,b]=>let val mp=opPrec operation val association=opAssoc operation
                          val lp=if association="left"then mp+1 else mp
                          val rp=if association="right"then mp+1 else mp
                          val result=printExp lp a env^operation^printExp rp b env
                     in if mp>=p then"("^result^")"else result end
          |_=>""end
    |Numb n=>numberString(D.force n)(precision env)
    |Var name=>name|EVar name=>name|BSError=>"ERROR"
 fun printAst(Set(name,value))env="Set "^name^" to "^printExp 10 value env
   |printAst(EvalSet(name,value))env="Eval\t"^printExp 10 value env^"\nSet\t"^name^" to "
   |printAst(Eval value)env="Eval "^printExp 10 value env
   |printAst SyntaxError _="Syntax error"|printAst NullCmd _=""
 fun printEnv [] _=""
   |printEnv((name,value)::rest)env=name^"\t"^printExp 10 value env^"\n"^printEnv rest env
 val help="Commands:\nclear        clear the environment\nenv          browse through the environment\nexit         quit\n?            display this help info\n$var = 'expr augment the environment\n$var = expr  eval and assign\nexpr         evaluate the expression\n\nwhere expr could be any of the following:\n\nEXP -> BINARY-EXP (EXP1,EXP2)\n     | UNARY-EXP (EXP)\n     | EXP1 OP EXP2\n\nBINARY-EXP -> add | sub | mul | div | equ\n            | ne  | lt  | gt | lte | gte\n\nUNARY-EXP -> sqrt | real | rat \n\nVAR -> a variable name\n"
 fun command text env=case text of"env"=>(printEnv env env,env)|"clear"=>("",initial())|"?"=>(help,env)
   |_=>let val ast=parse text
       in case ast of Set(name,value)=>(printAst ast env,enter name value env)
         |EvalSet(name,value)=>
           let val result=eval value env
           in(printAst ast env^printExp 10 result env,enter name result env)end
         |Eval value=>(printExp 10(eval value env)env,env)
         |_ =>(printAst ast env,env)end
 fun streamTranscript emit lines=
   let fun loop [] _=raise Fail"symalg input ended before exit"
         |loop("exit"::_)_=emit"-> "
         |loop(line::rest)env=
            let val _=emit"-> "
                val(output,next)=command line env
                val _=emit(output^"\n")
            in loop rest next end
   in loop lines(initial())end
 fun transcript lines=
   let val chunks=ref([]:string list)
       val _=streamTranscript(fn text=>chunks:=text:: !chunks)lines
   in String.concat(List.rev(!chunks))end
end
