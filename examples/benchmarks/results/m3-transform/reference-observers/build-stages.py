from pathlib import Path
import sys,json,subprocess
sys.setrecursionlimit(100000)
root=Path.cwd();p=Path(__file__).resolve().parent
names=[r.split('\t')[0]for r in(p/'observe.stdout').read_text().splitlines()]
for name in names:
 for stage in ['v0','v1','v3']:
  tree=json.loads((p/(name+'-'+stage+'.reference')).read_text())[4]
  (p/(name+'-'+stage+'-tree.reference')).write_text(json.dumps(tree,separators=(',',':'))+'\n')
(p/'stages-pilot.sml').write_text(r'''
functor StagesPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name stage tree=let val actual=K.dumpProgram tree^"\n"
   in if actual=read(name^"-"^stage^"-tree.reference")then print("PASS "^name^"/"^stage^"\n")
      else let val f=TextIO.openOut(name^"-"^stage^"-actual.json")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail(name^"/"^stage)end end
 fun run(name,raw)=let val name=K.showText name
      val prepared=K.label(K.use(K.sorted raw))
      val v0=K.label(K.use(K.sorted(K.inline(K.inline(K.use(K.sorted prepared))))))
      val v1=K.label(K.use(K.sorted(K.t1 v0)))
      val v3=K.label(K.use(K.sorted(K.t3 v1)))
   in check name"v0"v0;check name"v1"v1;check name"v3"v3 end
 val _=List.app run(K.F.toList(K.parsedCases()))
end
structure NeedStages=StagesPilotFn(BenchNeed)
structure StrictStages=StagesPilotFn(BenchStrict)
''')
parts=['types.sml','compare.sml','structure.sml','label.sml','inline.sml','t1346.sml','print.sml','serialize.sml','parsed-cases.sml']
(p/'transforms-check.sml').write_text(''.join((p/f).read_text()for f in parts)+'end\n')
files=[root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'transforms-check.sml',p/'stages-pilot.sml']
with(p/'stages-build.log').open('w')as log:subprocess.run(['bin/rune','--lint',*map(str,files),'-o',str(p/'stages.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'stages.log').open('w')as log:subprocess.run([str(root/'bin/runevm'),'stages.rbc'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
print((p/'stages.log').read_text())
