functor HartelTypecheckTestsFn(P:sig val eagerChildren:bool val policy:string end)=struct
 structure B=BenchHartelTypecheckProgramFn(P)
 structure Driver=BenchHartelTypecheckDriverFn(B)
 structure H=T
 open B.C
 val base=""
 fun label s="hartel-typecheck/"^P.policy^"/"^s
 fun read path=Driver.read(base^path)
 fun join []=""|join[x]=x|join(x::xs)=x^" "^join xs
 fun words values=join(rev(S.foldl(fn(x,xs)=>x::xs)[]values))
 val _=H.check(label "eight original inferred rows",fn()=>B.allRows()=read"rows.reference")
 val cases=[("identity",lambda"x"(variable"x")),
   ("self-application",lambda"x"(apply(variable"x")(variable"x"))),
   ("integer-application",apply(variable"0")(variable"1")),
   ("constant",lambda"x"(variable"1")),
   ("polymorphic-let",letExp["id"][lambda"x"(variable"x")](apply(variable"id")(variable"1"))),
   ("mutual-recursion",recursive["f","g"][lambda"x"(apply(variable"g")(variable"x")),lambda"y"(apply(variable"f")(variable"y"))](variable"f"))]
 val _=H.check(label "original extra expressions",fn()=>
   String.concat(List.map(fn(name,e)=>name^" "^check e^"\n")cases)=read"cases.reference")
 fun showSub Failure="failure"|showSub(OK phi)=join(List.map(fn x=>printType(phi x))["a","b","c"])
 val helpers=
   "nodups "^words(noDuplicates(S.fromList["a","b","a","c"]))^"\n"^
   "name "^nextName[2,0,1]^"\n"^
   "sequence "^join(S.take 4(nameSequence[0]))^"\n"^
   "compose "^printType(compose(delta"b"tint)(delta"a"(tv"b"))"a")^"\n"^
   "right-fold "^showSub(unifyList identity(S.fromList[(tv"a",tv"b"),(tv"a",tv"c")]))^"\n"^
   "arity "^showSub(unify identity(con"pair"(S.singleton(tv"a")),con"pair"(S.fromList[tint,tbool])))^"\n"^
   "unknowns "^words(envUnknowns(S.fromList[("x",scheme(S.empty())(tv"live")),("x",scheme(S.empty())(tv"hidden"))]))^"\n"^
   "occurs "^showSub(unify identity(tv"a",list(tv"a")))^"\n"^
   "unused-equation "^showSub(unifyList identity(S.cons(L.delay(fn()=>raise Fail "unused equation"),S.singleton(tint,tbool))))^"\n"
 val _=H.check(label "original substitutions, arity and shadowed range",fn()=>helpers=read"helpers.reference")
 val _=H.check(label "type child evaluation policy",fn()=>
   let val typ=con"unused"(S.singleton(L.delay(fn()=>raise Fail "unused type")))
   in if P.eagerChildren then((L.force typ;false)handle Fail why=>why="unused type")
      else(case L.force typ of TC(name,_)=>name="unused"|_=>false)end)
 val _=H.check(label "failure skips earlier equation payload",fn()=>
   case unifyList identity(S.cons(L.delay(fn()=>raise Fail "unused equation"),S.singleton(tint,tbool)))of
      Failure=>true|_=>false)
 val _=H.check(label "failure skips later expression",fn()=>
   let val bad=apply(variable"0")(variable"1")
       val expr=apply bad(L.delay(fn()=>raise Fail "unused expression"))
   in check expr="failure"end)
 val _=H.check(label "substitution remains a callable function",fn()=>
   let val calls=ref 0
       fun phi name=(calls:= !calls+1;tv name)
       val typ=substitute phi(con"list"(S.singleton(tv"a")))
       val _=printType typ
   in !calls=1 andalso printType typ="[<a>]"andalso !calls=1 end)
 val _=H.check(label "scheme bound variables exclude substitution",fn()=>
   let val next=substituteScheme(delta"a"tint)(scheme(S.singleton"a")(list(tv"a")))
   in case L.force next of Scheme(_,typ)=>printType typ="[<a>]"end)
 val _=H.check(label "original checksum",fn()=>B.benchmark 1=read"smoke.stdout")
 val _=H.check(label "original zero repetitions",fn()=>B.benchmark 0="0/0\n")
 val _=H.check(label "zero repetitions do not observe rows",fn()=>B.calculate 0(fn _=>raise Fail "unused row")="0/0\n")
 val _=H.check(label "consumer validates every row",fn()=>Driver.run["2",base^"rows.reference"]="29044/478")
 val _=H.check(label "row perturbation preserves weak checksum",fn()=>
   B.sumcode(S.fromList(String.explode(read"rows.reference")))=
   B.sumcode(S.fromList(String.explode(read"wrong-rows.reference"))))
 val _=H.check(label "same-checksum wrong row is rejected",fn()=>
   ((Driver.run["1",base^"wrong-rows.reference"];false)handle Fail why=>String.isPrefix "incorrect result:"why))
end
structure LazyHartelTypecheckTests=HartelTypecheckTestsFn(struct val eagerChildren=false val policy="lazy"end)
structure StrictHartelTypecheckTests=HartelTypecheckTestsFn(struct val eagerChildren=true val policy="strict"end)
