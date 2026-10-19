functor HappyTestsFn(structure D:BENCH_SUSPEND val strict:bool val label:string)=struct
 structure K=BenchHappyFn(D)
 structure L=BenchLazy
 structure F=K.F
 structure Fixtures=BenchHappyFixtures
 structure Check=BenchHappyCheckFn(K)
 exception Demanded
 fun demanded Demanded=true|demanded _=false
 fun failed(Fail _)=true|failed _=false
 fun test name f=T.check("happy/"^label^"/"^name,f)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun literal(name,mode,input,expected)=test("literal-"^name)(fn()=>
   let val actual=if mode="string"then K.readString(K.X.text input)else K.readCharacter(K.X.text input)
       val actual=case actual of NONE=>NONE|SOME(value,rest)=>
           SOME((if mode="string"then K.showString value else K.showCharacter value),K.X.string rest)
   in actual=expected end)
 val _=List.app literal Fixtures.literals
 fun code(name,arity,input,expected)=test("semantic-action-"^name)(fn()=>
   let val actual=(case K.doCheckCode arity(K.X.text input)of
          K.Rejected errors=>Fixtures.CodeErrors(List.map K.X.string(F.toList errors))
         |K.Succeeded value=>let val(code,used)=L.force value
            in Fixtures.CodeOK(K.X.string code,F.toList used)end)
         handle Fail _=>Fixtures.CodeException
   in actual=expected end)
 val _=List.app code Fixtures.codes

 val _=List.app(fn(input,wanted)=>test("reference-bound-"^input)(fn()=>
   case K.readReference(K.X.text input)of NONE=>not wanted
     |SOME(n,rest)=>wanted andalso n=1073741823 andalso K.X.string rest=""))
   [("1073741823",true),("1073741824",false),("0x3fffffff",true),("0x40000000",false),
    ("0o7777777777",true),("0o10000000000",false)]

 fun grammar name=
   let val(warnings,output)=K.generate(read(name^".y"))
       val _=test(name^"/warnings")(fn()=>K.X.string warnings=read(name^".warnings"))
       val _=test(name^"/complete-parser")(fn()=>K.X.string output=read(name^".reference"))
   in()end
 val _=List.app grammar Fixtures.grammars
 val _=test"driver-smoke"(fn()=>Check.run["precedence.y","precedence.reference","precedence.warnings"]="2575:0")
 val _=List.app(fn reference=>T.raises("happy/"^label^"/reject-"^reference,failed,
     fn()=>Check.run["precedence.y",reference,"precedence.warnings"]))["wrong.reference","truncated.reference"]
 val _=T.raises("happy/"^label^"/reject-warning-bytes",failed,
     fn()=>Check.run["precedence.y","precedence.reference","wrong.warnings"])
 val noNext=K.mkClosure(fn value=>fn _=>value=17)(fn _=>raise Demanded)17
 val _=test"closure-unused-next"(fn()=>noNext=17)
 val _=test"first-unused-suffix"(fn()=>K.NameSet.member 7
     (K.joinSymSets(fn n=>if n=1 then K.NameSet.singleton 7 else raise Demanded)(F.fromList[1,2])))
 val _=test"empty-first-skips-function"(fn()=>K.NameSet.member 0
     (K.joinSymSets(fn _=>raise Demanded)(F.empty())))
 val builds=ref 0 val reads=ref 0
 val array=K.A.array(0,0)(fn()=>(builds:= !builds+1;[(0,L.delay(fn()=>(reads:= !reads+1;42)))]))
 val _=test"array-construction-demand"(fn()=> !builds=0 andalso !reads=0)
 val _=test"array-cell-shared"(fn()=>K.A.sub array 0=42 andalso K.A.sub array 0=42 andalso !builds=1 andalso !reads=1)
 val hits=ref 0
 val mapped=F.map(fn n=>(hits:= !hits+1;n))(F.fromList[1,2,3])
 val _=test"finite-head-demand-and-sharing"(fn()=> !hits=(if strict then 3 else 0)andalso
     F.nth mapped 0=1 andalso F.nth mapped 0=1 andalso !hits=(if strict then 3 else 1))
 val ast=case K.parse(K.X.input(read"precedence.y"))1 of K.X.Ok ast=>ast|_=>raise Fail"fixture parser"
 val g=case K.mangler"TestInput.y"ast of K.Succeeded root=>L.force root|_=>raise Fail"fixture mangler"
 fun poison()=L.delay(fn()=>raise Demanded)
 val _=test"goto-array-skips-undemanded-states"(fn()=>let val _=K.genGotoTable g(poison())in true end)
 val _=test"action-array-skips-undemanded-states"(fn()=>let val _=K.genActionTable g(K.mkFirst g)(poison())in true end)
 fun prefix()=K.produceParser g(poison())(poison())
       (D.delay(fn()=>SOME(K.X.text"A")))(D.delay(fn()=>NONE))
 val _=if strict then T.raises("happy/"^label^"/strict-generated-output",demanded,fn()=>prefix())
   else test"header-skips-undemanded-tables"(fn()=>F.nth(prefix())0= #"A")
end
structure NeedHappyTests=HappyTestsFn(structure D=BenchNeed val strict=false val label="need")
structure StrictHappyTests=HappyTestsFn(structure D=BenchStrict val strict=true val label="strict")
structure HappySetTests=struct
 structure S=BenchHappySetFn(type item=int val compare=Int.compare)
 structure L=BenchLazy
 fun decimal n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun array xs="["^String.concatWith","xs^"]"
 fun shape S.Tip="[0]"
   |shape(S.Bin(n,x,l,r))=array[decimal n,decimal x,shape l,shape r]
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun one(index,xs,ys,m)=
   let val a=S.fromList(fn()=>xs)val b=S.fromList(fn()=>ys)
       val trees=[a,b,S.union a b,S.difference a b,S.filter(fn n=>n mod m<>0)a]
       val expected=String.tokens(fn c=>c= #"\n")(read("set-"^Int.toString index^".reference"))
       val _=List.app(fn((i,tree),wanted)=>T.check("happy/set-"^Int.toString index^"/shape-"^Int.toString i,
           fn()=>shape(L.force tree)=wanted andalso (ignore(S.validate(L.force tree));true)))
           (ListPair.zip(ListPair.zip([0,1,2,3,4],trees),expected))
       val _=T.check("happy/set-"^Int.toString index^"/streamed-fromList",
           fn()=>shape(L.force(S.fromStream(S.streamFromList xs)))=shape(L.force a))
   in()end
 val _=List.app one BenchHappyFixtures.sets
end
