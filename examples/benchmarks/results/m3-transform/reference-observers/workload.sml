 fun prepare input=
   let val tokens=lexer input
       val directory=concat(findPragma(text"module")(empty())tokens)
       val includes=map(fn file=>cat[text"include \"",file,text".m\"\n"])(findPragma(text"include")(empty())tokens)
       val tree=F.defer(fn()=>label(use(sorted(parse(dropPragma tokens)))))
   in(directory,includes,input,tree)end
 fun oneTest name description transform(directory,includes,_,tree)=
   let val next=F.defer(fn()=>transform tree)
       val rendered=cat[text"cat - <<'end' > ",directory,text".dir/",name,text".m\n|| ",
          directory,text".dir ",name,text" = ",description,text"\n||\n",
          concat(map(fn includeText=>append(text"%")includeText)includes),text"||\n",printProgram next,text"\nend\n"]
   in(directory,includes,rendered,next)end
 fun test quad=
   let val v=oneTest(text"v")(text"v")(fn x=>x)quad
       val v0=oneTest(text"v0")(text"inl v")(fn x=>label(use(sorted(inline(inline(use(sorted x)))))))v
       val v1=oneTest(text"v1")(text"t1 v0")(fn x=>label(use(sorted(t1 x))))v0
       val v3=oneTest(text"v3")(text"t3 v1")(fn x=>label(use(sorted(t3 x))))v1
       val v5=oneTest(text"v5")(text"t5 v3")(fn x=>sorted(t5 x))v3
       val v6=oneTest(text"v6")(text"t6 v5")(fn x=>inline(t6 x))v5
       fun rendered(_,_,text,_)=text
   in concat(list(List.map rendered[v,v0,v1,v3,v5,v6]))end
 fun cycle roots=
   let val root=ref NONE
       fun cells []=L.delay(fn()=>case !root of SOME value=>L.force value|NONE=>raise Fail"transform cycle not tied")
         |cells(value::rest)=L.delay(fn()=>CNext(value,cells rest))
       val result=cells roots
       val _=root:=SOME result
   in result end
 fun finiteTake 0 _=empty()
   |finiteTake n values=D.delay(fn()=>case L.force values of CEmpty=>F.Nil
      |CNext(value,rest)=>F.Cons(D.delay(fn()=>L.force value),finiteTake(n-1)rest))
 fun run count selected=
   let val roots=List.map(fn(name,input,expected)=>
         L.delay(fn()=>(name,prepare(text input),expected)))selected
       val work=finiteTake count(cycle roots)
       fun checked(name,quad,expected)=
         let val actual=F.length(test quad)
         in if actual=expected then actual else raise Fail("incorrect result: transform report length for "^name)end
       val values=map checked work
       val total=F.foldl(fn sum=>fn value=>D.delay(fn()=>D.force sum+value))(fromInt 0)values
   in D.force total end
