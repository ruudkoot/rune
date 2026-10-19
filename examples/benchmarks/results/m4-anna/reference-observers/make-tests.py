from pathlib import Path
import re,shutil
root=Path.cwd();p=Path(__file__).resolve().parent
data=root/'tests/benchmarks/data/nofib-anna';data.mkdir(exist_ok=True)
def copy(src,dest):
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
for name in ['anna.faststdin','anna.stdin','anna.slowstdin','runtime_files/anna_table']:copy(p/'source'/name,data/'inputs'/name)
for pattern in ['parsed-*.reference','dependency-*.reference','lift-*.reference','types-*.reference','typed-tree-*.reference','eta-tree-*.reference','type-environment-*.reference','analysis-*.reference','full-*.reference']:
 for f in p.glob(pattern):copy(f,data/f.name)
for name in ['domains.reference','size.reference','frontier.reference','lattice-table.reference']:copy(p/name,data/name)
(data/'.gitattributes').write_text('# Exact independent original source observations.\n** -whitespace\n')
code=r'''(* Independent observations of pinned original Anna functions.
   Every kernel instance is shared across its policy's semantic checks. *)
functor NofibAnnaTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibAnnaFn(D)
 structure L=BenchLazy
 val root="tests/benchmarks/data/nofib-anna/"
 fun read name=BenchApplicationTestIO.read(root^name)
 fun compare suffix expected actual=BenchApplicationTestIO.compare("nofib-anna/"^label^"/"^suffix,expected,actual)
 structure Observe=struct
  open K
'''
code+=(p/'observe.sml').read_text()+(p/'type-observe.sml').read_text()
code+=r'''
 end
 val builtinNames=K.map(fn entry=> #1(D.force entry))K.baseAnnotations
 fun profile(profile,file)=
   let val source=read("inputs/"^file)
       val parsed=K.parseSyntax(K.lex(K.int 1)(K.input source))
       val _=compare(profile^"/parsed")(read("parsed-"^profile^".reference"))(Observe.observeProgram parsed)
       val(types,_)=D.force parsed
       val groups=K.typeDependency types
       val grouping=Observe.showList(fn(recursive,names)=>"("^(if D.force recursive then"True"else"False")^","^Observe.namesShown names^")")groups
       val _=compare(profile^"/dependency")(read("dependency-"^profile^".reference"))grouping
       val(_,atomic)=K.parseCore(K.input source)
       val(types,e)=D.force atomic
       fun finalLift(mode,pretty)=
         let val(e,parameters)=L.force(K.lambdaLift builtinNames e pretty)
             val actual="("^Observe.observeCore e^","^Observe.showList(fn(n,ps)=>"("^Observe.quoteName n^","^Observe.namesShown ps^")")parameters^")"
         in compare(profile^"/lift-"^mode)(read("lift-final-"^mode^"-"^profile^".reference"))actual end
       val _=List.app finalLift[("pretty",true),("raw",false)]
       val(e,_)=L.force(K.lambdaLift builtinNames e true)
       val(words,result)=K.checkTypes K.baseTypes(K.singleton(K.int 1),K.singleton(K.int 0))(K.pair types e)
       val _=compare(profile^"/types")(read("types-"^profile^".reference"))(K.string words)
       val(tree,environment)=case L.force result of K.Ok value=>D.force value|_=>raise Fail"source typecheck failed"
       val _=compare(profile^"/typed-tree")(read("typed-tree-"^profile^".reference"))(Observe.observeTyped tree)
       val _=compare(profile^"/eta-tree")(read("eta-tree-"^profile^".reference"))(Observe.observeTyped(K.etaAbstract tree))
       val _=compare(profile^"/type-environment")(read("type-environment-"^profile^".reference"))
          (Observe.showList(fn(n,t)=>"("^Observe.quoteName n^","^Observe.observeType t^")")environment)
       val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
       val report=K.string(K.strictAnalyze table(K.F.empty())(K.input source))
   in compare(profile^"/complete-report")(read("full-"^profile^".reference"))report end
 val _=List.app profile[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
 val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
 val _=compare"complete-lattice-table"(read"lattice-table.reference")(Observe.observeTable table)
'''
# Reuse the independently defined structural observers, not expected values
# computed by the portable functions being tested.
domain=(p/'domain-probe.sml').read_text()
helpers=domain[domain.index(' fun list'):domain.index(' val source=')]
code+='\n structure Domains=struct\n'+helpers
a=domain.index('val cases=');b=domain.index(' fun one(domain,values)',a)
code+=domain[a:b]
code+=r'''
 val source=TextIO.openIn(root^"domains.reference")
 val index=ref 0
 fun check phase actual=
   let val expected=case TextIO.inputLine source of SOME s=>s|NONE=>raise Fail"domain oracle EOF"
   in compare("domain-"^Int.toString(!index)^"/"^phase)expected(actual^"\n")end
'''
a=domain.index(' fun one(domain,values)');b=domain.index('\nend\nstructure Need=',a)
code+=domain[a:b]+'\n end\n'
size=(p/'size-probe.sml').read_text()
a=size.index(' fun seq');b=size.index(' val input=',a)
code+='\n structure Sizes=struct\n'+size[a:b]
code+=r'''
 val input=TextIO.openIn(root^"size.reference")
 val counter=ref 0
 fun check actual=
   let val expected=case TextIO.inputLine input of SOME s=>s|NONE=>raise Fail"size oracle EOF"
   in counter:= !counter+1;compare("size-"^Int.toString(!counter))expected(actual^"\n")end
'''
a=size.index('val cases=');b=size.index('\nend\nstructure Need=',a)
code+=size[a:b]+'\n end\n'
frontier=(p/'frontier-probe.sml').read_text()
code+='\n structure Frontiers=struct\n'+helpers
code+=r'''
 val source=TextIO.openIn(root^"frontier.reference")
 val counter=ref 0
 fun check actual=
   let val expected=case TextIO.inputLine source of SOME s=>s|NONE=>raise Fail"frontier oracle EOF"
   in counter:= !counter+1;compare("frontier-"^Int.toString(!counter))expected(actual^"\n")end
'''
a=frontier.index(' fun finite');b=frontier.index('\nend\nstructure Need=',a)
code+=frontier[a:b]+'\n end\n'
analysis=(p/'analysis-probe.sml').read_text()
code+='\n structure Analysis=struct\n'+helpers
a=analysis.index(' fun oneSize');b=analysis.index(' fun one(profile,file)=',a)
code+=analysis[a:b].replace('K.quoteName','Observe.quoteName').replace('K.showDomain','Observe.showDomain').replace('K.namesShown','Observe.namesShown')
code+=r'''
 fun one(profile,file)=
   let val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
       val(_,result)=K.prepareAnalysis(read("inputs/"^file))table
       val expected=TextIO.openIn(root^"analysis-"^profile^".reference")
       val count=ref 0
       fun loop values=case D.force values of K.F.Nil=>()
         |K.F.Cons(x,rest)=>
           let val actual=info x^"\n"
               val wanted=case TextIO.inputLine expected of SOME s=>s|NONE=>raise Fail"analysis reference EOF"
           in count:= !count+1;compare(profile^"/analysis-"^Int.toString(!count))wanted actual;loop rest end
       val _=loop result
       val _=T.check("nofib-anna/"^label^"/"^profile^"/analysis-complete",fn()=>not(Option.isSome(TextIO.inputLine expected)))
   in TextIO.closeIn expected end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
 end
'''
code+=r'''
 val _=List.app(fn(name,want)=>T.check("nofib-anna/"^label^"/hash/"^name,fn()=>
    let val table=K.readTable(K.input(read"inputs/runtime_files/anna_table"))
        val source=read("inputs/"^name)
        val actual=K.benchmark(K.input source)table
    in K.signedHash actual=want end))
   [("anna.faststdin","-887277049712337739"),("anna.stdin","2911885587254673792"),("anna.slowstdin","1779591958989696265")]
 structure Check=BenchNofibAnnaCheckFn(K)
 val _=T.check("nofib-anna/"^label^"/zero-repetitions-skip-source-and-table",fn()=>
     Check.run["0","missing-anna-source","0"]="0")
end
structure NeedAnna=NofibAnnaTestsFn(structure D=BenchNeed val label="lazy")
structure StrictAnna=NofibAnnaTestsFn(structure D=BenchStrict val label="strict")
(* Essential sharing is checked on the actual finite representation. *)
structure AnnaDemand=BenchNofibAnnaFn(BenchNeed)
val forced=ref 0
val tail:Word64.word AnnaDemand.F.seq=BenchNeed.delay(fn()=>(forced:= !forced+1;AnnaDemand.F.Nil))
val values=AnnaDemand.F.cons(BenchNeed.delay(fn()=>0w7:Word64.word),tail)
val _=T.check("nofib-anna/lazy/unneeded-list-tail",fn()=>
   AnnaDemand.equalInt(AnnaDemand.head values)(AnnaDemand.int 7)andalso !forced=0)
val _=AnnaDemand.null(AnnaDemand.tail values)
val _=AnnaDemand.null(AnnaDemand.tail values)
val _=T.check("nofib-anna/lazy/shared-list-tail",fn()=> !forced=1)
val eof=AnnaDemand.lex(AnnaDemand.int 1)(AnnaDemand.input"")
val _=T.check("nofib-anna/singleton-eof",fn()=>
  case BenchLazy.force eof of AnnaDemand.C.Nil=>false
   |AnnaDemand.C.Cons(token,rest)=>
      let val(line,name)=BenchLazy.force token
      in AnnaDemand.equalInt line(AnnaDemand.int 999999)andalso AnnaDemand.string name="$$$"
         andalso(case BenchLazy.force rest of AnnaDemand.C.Nil=>true|_=>false)end)
'''
# The final check is outside the policy functor.
code=code.replace('K.showDomain','Observe.showDomain')
code=code.replace('val token=L.force(AnnaDemand.headControl','val token=BenchLazy.force(AnnaDemand.headControl')
(root/'tests/benchmarks/nofib-anna-tests.sml').write_text(code)
files=sorted(str(f.relative_to(root))for f in data.rglob('*')if f.is_file()and f.name!='FILES')
(data/'FILES').write_text('\n'.join(files)+'\n')
runner=root/'tests/benchmarks/check-nofib-applications.sh'
runner.write_text(runner.read_text().replace('parser|reptile|hpg|fluid)','parser|reptile|hpg|fluid|anna)'))
(root/'tests/benchmarks/check-nofib-anna.sh').write_text('#!/bin/sh\nset -eu\nexec sh "$(dirname "$0")/check-nofib-applications.sh" anna\n')
# Preserve one contiguous overview table.
f=root/'examples/benchmarks/README.md';f.write_text(re.sub(r'\n+(\| \[anna-lazy\])',r'\n\1',f.read_text(),count=1))
print('created independent semantic runner and',len(files),'source reference/data files')
