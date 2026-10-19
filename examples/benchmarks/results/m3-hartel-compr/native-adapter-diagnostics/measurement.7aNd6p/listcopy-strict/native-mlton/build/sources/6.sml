functor BenchHartelComprFn (D : BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  type text=char S.stream
  datatype 'a node=Nil|Cons of 'a*'a node D.t
  type 'a seq='a node D.t
  datatype expr=Apl of text*expr D.t seq|Cmp of expr D.t*qual D.t seq
    |Let of def D.t seq*expr D.t|Cns of text|Var of text
  and def=Def of text*text seq*expr D.t
  and qual=Gen of int*text*expr D.t|Fil of expr D.t
  fun empty()=D.delay(fn()=>Nil)
  fun fromList []=empty()|fromList(x::xs)=D.delay(fn()=>Cons(x,fromList xs))
  fun map f xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(x,rest)=>Cons(f x,map f rest))
  fun append xs ys=D.delay(fn()=>case D.force xs of Nil=>D.force(ys())|Cons(x,rest)=>Cons(x,append rest ys))
  fun nth xs n=case D.force xs of Nil=>raise Subscript|Cons(x,rest)=>if n=0 then x else nth rest(n-1)
  fun text value=
    let fun loop i=L.delay(fn()=>if i=String.size value then S.Nil
          else S.Cons(L.delay(fn()=>String.sub(value,i)),loop(i+1)))
    in loop 0 end
  fun cat []=S.empty()
    |cat[last]=L.delay(fn()=>L.force(last()))
    |cat(first::rest)=L.delay(fn()=>L.force(S.append(first())(cat rest)))
  fun number n=L.delay(fn()=>L.force(text(Int.toString n)))
  fun variable name=D.delay(fn()=>Var name)
  fun constant value=D.delay(fn()=>Cns value)
  fun app name arguments=D.delay(fn()=>Apl(name,fromList(arguments())))
  fun letExpr definitions body=D.delay(fn()=>Let(fromList(definitions()),body()))
  fun definition name arguments body=D.delay(fn()=>Def(name,fromList arguments,body()))
  fun generator n name body=D.delay(fn()=>Gen(n,name,body()))
  fun filter body=D.delay(fn()=>Fil(body()))
  val inputVars=List.map(fn name=>(name,variable(text name)))["a","b","c","d","h","q","x","y","z","xs","ys"]
  val inputConstants=List.map(fn value=>(value,constant(text value)))["0","1","true","false"]
  fun lookup key []=raise Fail "unrecognized source constant"
    |lookup key((name,value)::rest)=if key=name then value else lookup key rest
  val makeApp=app
  val makeLet=letExpr
  val makeDefinition=definition
  structure Data=BenchHartelComprDataFn(struct
    type expr=expr D.t type def=def D.t type qual=qual D.t
    fun var name=lookup name inputVars
    fun cns value=lookup value inputConstants
    fun app(name,args)=makeApp(text name)args
    fun cmp(body,quals)=D.delay(fn()=>Cmp(body(),fromList(quals())))
    fun letExpr(defs,body)=makeLet defs body
    fun definition(name,args,body)=makeDefinition(text name)(List.map text args)body
    fun gen(n,name,body)=generator n(text name)body
    val fil=filter
  end)
  val program=fromList Data.program
  fun transformDefinition input=D.delay(fn()=>case D.force input of Def(name,args,body)=>Def(name,args,transform body name))
  and transform input function=D.delay(fn()=>case D.force input of
      Apl(name,args)=>Apl(name,map(fn x=>transform x function)args)
    |Cmp(body,quals)=>D.force(qualify body quals(constant(text "[]"))function)
    |Let(defs,body)=>Let(map(fn value=>D.delay(fn()=>case D.force value of Def(name,args,body)=>Def(name,args,transform body function)))defs,transform body function)
    |Cns value=>Cns value|Var name=>Var name)
  and qualify body qualifiers after function=D.delay(fn()=>case D.force qualifiers of
      Nil=>D.force(app(text ":")(fn()=>[transform body function,transform after function]))
    |Cons(first,rest)=>(case D.force first of
       Fil predicate=>D.force(app(text "if")(fn()=>[transform predicate function,qualify body rest after function,transform after function]))
     |Gen(n,name,values)=>
       let val helper=cat[fn()=>function,fn()=>text "_h",fn()=>number n]
           val listName=cat[fn()=>function,fn()=>text "_l",fn()=>number n]
           val tailName=cat[fn()=>function,fn()=>text "_t",fn()=>number n]
           val listVar=variable listName val tailVar=variable tailName
       in D.force(letExpr(fn()=>[
         definition helper[listName](fn()=>app(text "if")(fn()=>[
           app(text "null")(fn()=>[listVar]),transform after function,
           letExpr(fn()=>[
             definition name[](fn()=>app(text "hd")(fn()=>[listVar])),
             definition tailName[](fn()=>app(text "tl")(fn()=>[listVar]))])
             (fn()=>qualify body rest(app helper(fn()=>[tailVar]))function)]))])
         (fn()=>app helper(fn()=>[transform values function])))end))
  fun repeat 0=empty()
    |repeat n=D.delay(fn()=>D.force(append program(fn()=>repeat(n-1))))
  fun translated n=map transformDefinition(repeat n)
  fun prefixed prefix render values=L.delay(fn()=>case D.force values of Nil=>S.Nil
    |Cons(value,rest)=>L.force(S.append(S.append(text prefix)(render value))(prefixed prefix render rest)))
  fun showDefinition value=L.delay(fn()=>case D.force value of Def(name,args,body)=>L.force(cat
    [fn()=>name,fn()=>prefixed " " (fn value=>value)args,fn()=>text " = ",fn()=>showExpr body]))
  and showExpr value=L.delay(fn()=>L.force(case D.force value of
      Var name=>name|Cns value=>value
    |Apl(name,args)=>
       if let val c=S.head name in (c>= #"a"andalso c<= #"z")orelse(c>= #"A"andalso c<= #"Z")end
       then cat[fn()=>text "(",fn()=>name,fn()=>prefixed " " showExpr args,fn()=>text ")"]
       else cat[fn()=>text "(",fn()=>showExpr(nth args 0),fn()=>name,fn()=>showExpr(nth args 1),fn()=>text ")"]
    |Cmp(body,quals)=>cat[fn()=>text "[",fn()=>showExpr body,fn()=>text " | ",
       fn()=>S.tail(prefixed ";" showQualifier quals),fn()=>text "]"]
    |Let(defs,body)=>(case D.force defs of Nil=>showExpr body|_=>cat
       [fn()=>text "(LET ",fn()=>S.tail(prefixed ";\n" showDefinition defs),fn()=>text " IN  ",fn()=>showExpr body,fn()=>text ")"])))
  and showQualifier value=L.delay(fn()=>L.force(case D.force value of
      Fil body=>showExpr body|Gen(_,name,body)=>cat[fn()=>name,fn()=>text " <- ",fn()=>showExpr body]))
  fun showProgram values=L.delay(fn()=>case D.force values of Nil=>S.Nil
    |Cons(first,rest)=>L.force(S.append(S.append(showDefinition first)(text ";\n"))(showProgram rest)))
  fun copy source=L.delay(fn()=>case L.force source of S.Nil=>S.Nil|S.Cons(value,rest)=>S.Cons(value,copy rest))
  fun output copying n=let val result=showProgram(translated n)in if copying then copy result else result end
  fun lengthFrom(count,xs)=case L.force xs of S.Nil=>count
    |S.Cons(_,rest)=>lengthFrom(count+1,rest)
  fun length source=lengthFrom(0,source)
  fun outputLength copying n=length(output copying n)
end
