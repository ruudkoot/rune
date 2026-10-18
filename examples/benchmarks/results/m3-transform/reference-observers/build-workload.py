from pathlib import Path
import subprocess
root=Path.cwd();p=Path(__file__).resolve().parent
base=(p/'kernel.sml').read_text();assert base.endswith('end\n')
base=base[:-4]+(p/'workload.sml').read_text()+'end\n'
(p/'workload-kernel.sml').write_text(base)
(p/'workload-pilot.sml').write_text(r'''
functor WorkloadPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check(name,input,expected)=
   let val quad=K.prepare(K.text input)val report=K.test quad
       val actual=String.implode(K.F.toList report)
   in if actual=read(name^"-report.reference")andalso K.F.length report=expected
      then print("PASS "^name^"/complete-report\n")
      else let val f=TextIO.openOut(name^"-report-actual.txt")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail name end end
 val _=List.app check BenchTransformInputs.all
 val _=print("SMOKE "^Int.toString(K.run 8 BenchTransformInputs.selected)^"\n")
end
structure NeedWorkload=WorkloadPilotFn(BenchNeed)
structure StrictWorkload=WorkloadPilotFn(BenchStrict)
''')
files=[root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'inputs.sml',p/'workload-kernel.sml',p/'workload-pilot.sml']
with(p/'workload-build.log').open('w')as log:subprocess.run(['bin/rune','--lint',*map(str,files),'-o',str(p/'workload.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'workload.log').open('w')as log:subprocess.run([str(root/'bin/runevm'),'workload.rbc'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
print((p/'workload.log').read_text())
