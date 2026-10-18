from pathlib import Path
import subprocess,shutil,json,sys
sys.setrecursionlimit(100000)
root=Path.cwd();p=Path(__file__).resolve().parent;data=p/'data';data.mkdir(exist_ok=True)
names=[r.split('\t')[0]for r in(p/'observe.stdout').read_text().splitlines()]
for name in names:
 for suffix in ['.input','-tokens.reference','-parse.reference','-prepared-tree.reference','-v0-tree.reference','-v1-tree.reference','-v3-tree.reference','-v5-tree.reference','-v6-tree.reference','-report.reference']:
  shutil.copy(p/(name+suffix),data/(name+suffix))
t=r'''
functor TransformTestsFn(structure D:BENCH_SUSPEND val strict:bool val label:string)=struct
 structure K=BenchTransformFn(D)
 structure L=BenchLazy
 structure Check=BenchTransformCheckFn(K)
 exception Demanded
 fun demand Demanded=true|demand _=false
 fun test name f=T.check("transform/"^label^"/"^name,f)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun observation name stage actual=test(name^"/"^stage)(fn()=>actual^"\n"=read(name^"-"^stage^".reference"))
 fun run(name,input,expected)=
   let val chars=K.text input
       val tokens=K.lexer chars
       val raw=K.parse(K.dropPragma tokens)
       val _=observation name"tokens"(K.dumpTokens tokens)
       val _=observation name"parse"(K.dumpProgram raw)
       val prepared=K.label(K.use(K.sorted raw))
       val v0=K.label(K.use(K.sorted(K.inline(K.inline(K.use(K.sorted prepared))))))
       val v1=K.label(K.use(K.sorted(K.t1 v0)))
       val v3=K.label(K.use(K.sorted(K.t3 v1)))
       val v5=K.sorted(K.t5 v3)
       val v6=K.inline(K.t6 v5)
       val _=List.app(fn(stage,tree)=>observation name(stage^"-tree")(K.dumpProgram tree))
         [("prepared",prepared),("v0",v0),("v1",v1),("v3",v3),("v5",v5),("v6",v6)]
       val report=K.test(K.prepare chars)
       val _=test(name^"/complete-report")(fn()=>K.showText report=read(name^"-report.reference"))
       val _=test(name^"/length-consumer")(fn()=>K.F.length report=expected)
   in()end
 val _=List.app run BenchTransformInputs.all
 val _=test"smoke-cycle"(fn()=>K.run 8 BenchTransformInputs.selected=28275)
 val _=test"cycle-first"(fn()=>K.run 1 BenchTransformInputs.selected=4384)
 val _=test"cycle-wrap-prefix"(fn()=>K.run 9 BenchTransformInputs.selected=32659)
 val _=test"zero-count-skips-invalid-global"(fn()=>K.run 0[("unused","\"",0)]=0)
 val _=test"zero-count-empty-cycle"(fn()=>K.run 0[]=0)
 val _=test"driver-zero"(fn()=>Check.run["0"]="0")
 val _=test"driver-smoke"(fn()=>Check.run["8"]="28275")
 val _=T.raises("transform/"^label^"/reject-wrong-length",fn Fail _=>true|_=>false,
   fn()=>let val(name,input,expected)=BenchTransformInputs.lookup"fft"in K.run 1[(name,input,expected+1)]end)
 val badInput:K.tokenStream=L.delay(fn()=>raise Demanded)
 val pure:int D.t K.pattern=K.pure(K.fromInt 42)
 val _=test"empty-pattern-skips-input"(fn()=>let val(value,_)=K.cHead(pure badInput)in D.force value=42 end)
 val _=test"first-result-skips-alternative"(fn()=>let val(value,_)=K.cHead(K.patFirst pure(fn _=>raise Demanded)badInput)
   in D.force value=42 end)
 val token=L.delay(fn()=>K.CNext(L.delay(fn()=>K.NAME(K.text"x")),K.cEmpty()))
 val hits=ref 0
 val convert:K.expr K.pattern=K.patMatch(fn _=>true)(fn _=>(hits:= !hits+1;K.var(K.text"x")))
 val _=test"attribute-callback-demand"(fn()=>let val(value,_)=K.cHead(convert token)
   in !hits=(if strict then 1 else 0)andalso K.dumpExpr value="[\"F_Var\",\"x\"]"andalso
      K.dumpExpr value="[\"F_Var\",\"x\"]"andalso !hits=1 end)
 val poison:K.expr K.pattern=K.patMatch(fn _=>true)(fn _=>raise Demanded)
 val _=if strict then T.raises("transform/"^label^"/strict-attribute",demand,fn()=>K.cHead(poison token))
   else test"lazy-unused-attribute"(fn()=>let val _=K.cHead(poison token)in true end)
 val _=test"parser-keeps-first-program-prefix"(fn()=>
   K.dumpProgram(K.parse(K.lexer(K.text"output = 1; @")))=
   "[\"(:)\",[\"F_Caf\",[\"(:)\",\"output\",[\"[]\"]],[\"F_Lit\",\"1\"]],[\"[]\"]]")
 val _=test"source-real-digit-plus"(fn()=>
   K.dumpTokens(K.lexer(K.text"1+2"))="[\"(:)\",[\"F_NUMB\",\"1+2\"],[\"[]\"]]")
 val _=test"source-comment-skip"(fn()=>
   K.dumpTokens(K.lexer(K.text"|| ignored\nx"))="[\"(:)\",[\"F_NAME\",\"x\"],[\"[]\"]]")
 val _=test"source-dangling-pragma-kept"(fn()=>
   K.dumpTokens(K.dropPragma(K.lexer(K.text"%module")))="[\"(:)\",[\"F_PRAG\",\"module\"],[\"[]\"]]")
 val _=test"source-inline-self-excluded"(fn()=>
   let val f=K.text"f"val x=K.text"x"
       val program=K.one(K.def f(K.one x)(K.ap f(K.one(K.var x)))(K.noWhere()))
   in K.dumpProgram(K.inline program)=K.dumpProgram program end)
 val _=test"source-vars-ignore-cons-state"(fn()=>
   K.showText(K.head(K.vars(K.consExpr(K.fromInt 1)(K.var(K.text"state"))(K.var(K.text"stream")))))="stream")
 val _=test"source-vars-ignore-maps-state"(fn()=>
   K.F.length(K.vars(K.mapsExpr(K.fromInt 1)(K.text"f")(K.text"g")(K.var(K.text"state"))(K.empty())))=0)
 val _=test"numeric-label-comparison"(fn()=>
   K.compareExpr(K.tailExpr(K.fromInt 1)(K.var(K.text"x")))(K.tailExpr(K.fromInt 3)(K.var(K.text"x")))= ~2)
 val _=test"comparison-constructor-order"(fn()=>
   K.compareExpr(K.tailExpr(K.fromInt 1)(K.var(K.text"x")))(K.var(K.text"x"))= ~6)
 val _=if strict then T.raises("transform/"^label^"/strict-finite-data",demand,fn()=>D.delay(fn()=>raise Demanded))
   else test"zip-empty-skips-right"(fn()=>K.null(K.zip(K.empty())(D.delay(fn()=>raise Demanded))))
 val _=test"grammar-caches-populated"(fn()=>Option.isSome(!K.cacheProgram)andalso Option.isSome(!K.cacheExpr))
end
structure NeedTransformTests=TransformTestsFn(structure D=BenchNeed val strict=false val label="need")
structure StrictTransformTests=TransformTestsFn(structure D=BenchStrict val strict=true val label="strict")
structure TransformNeedDemand=struct
 structure K=BenchTransformFn(BenchNeed)
 structure L=BenchLazy
 exception Demanded
 fun expected Demanded=true|expected _=false
 val badChar:char L.delay=L.delay(fn()=>raise Demanded)
 val chars=K.F.cons(badChar,K.empty())
 val _=T.check("transform/need/length-skips-character-content",fn()=>K.F.length(K.printExpr(K.var chars))=1)
 val _=T.raises("transform/need/full-render-demands-character",expected,fn()=>K.showText(K.printExpr(K.var chars)))
 val _=T.raises("transform/need/indent-matches-character",expected,fn()=>K.F.length(K.indent chars))
 val badExpr:K.expr=L.delay(fn()=>raise Demanded)
 val _=T.check("transform/need/vars-skip-cons-state",fn()=>K.F.length(K.vars(K.consExpr(K.fromInt 1)badExpr(K.var(K.text"x")))))=1)
 val badLabel:int L.delay=L.delay(fn()=>raise Demanded)
 val _=T.check("transform/need/constructor-comparison-skips-label",fn()=>
   K.compareExpr(K.tailExpr badLabel badExpr)(K.var(K.text"x"))= ~6)
 val _=T.check("transform/need/earlier-comparison-skips-name",fn()=>
   K.compareExpr(K.mapExpr(K.fromInt 1)chars(K.empty()))(K.mapExpr(K.fromInt 3)chars(K.empty()))= ~2)
 val _=T.check("transform/need/expression-name-skips-irrelevant-label",fn()=>
   K.showText(K.expressionName badLabel(K.var(K.text"x")))="x")
end
'''
# One closing parenthesis belongs after the predicate, not after the first argument.
t=t.replace('K.var(K.text"x")))))=1)','K.var(K.text"x"))))=1)')
(p/'tests.sml').write_text(t)
files=[root/'tests/basis/harness.sml',root/'examples/benchmarks/shared/input.sml',root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'inputs.sml',p/'kernel-final.sml',p/'check.sml',p/'tests.sml',root/'tests/basis/finish.sml']
(p/'sources.txt').write_text(''.join(str(f)+'\n'for f in files));(p/'data-list').write_text(''.join(f.name+'\n'for f in sorted(data.iterdir())))
with(p/'tests-build.log').open('w')as log:subprocess.run(['bin/rune','--lint',*map(str,files),'-o',str(p/'tests.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'tests.log').open('w')as log:subprocess.run([str(root/'bin/runevm'),str(p/'tests.rbc')],cwd=data,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
print((p/'tests.log').read_text().splitlines()[-1])
