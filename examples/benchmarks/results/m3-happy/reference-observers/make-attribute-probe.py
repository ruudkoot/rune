from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
parts=['types.sml','abstract.sml','literals.sml']
text=''.join((p/f).read_text()for f in parts)
text+=(p/'parser-serialize.sml').read_text().split(' fun jsonText')[0]
text+=''.join((p/f).read_text()for f in ['attributes-prefix.sml','attributes-reductions.sml','attributes-actions.sml'])
text+=(p/'attributes-runtime.sml').read_text().removesuffix('\n end\n')
text+=(p/'attributes-serialize.sml').read_text()+'\nend\nend\n'
(p/'attribute-observe-kernel.sml').write_text(text)
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
val failures=ref 0
functor AttributeProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 fun one name=List.app(fn mode=>
   let val root="tests/out/benchmarks/nofib-happy-originals/attribute-data/"
       val actual=K.AG.json mode(read(root^name^".input"))^"\n"
   in if actual=read(root^name^"-"^mode^".reference")then print("PASS "^label^" "^name^" "^mode^"\n")
      else let val f=TextIO.openOut(root^name^"-"^mode^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;failures:= !failures+1;print("FAIL "^label^" "^name^" "^mode^"\n")end end)["tokens","rules"]
 val _=List.app one CASES
end
structure NeedAttributes=AttributeProbeFn(structure D=BenchNeed val label="need")
structure StrictAttributes=AttributeProbeFn(structure D=BenchStrict val label="strict")
val _=OS.Process.exit(if !failures=0 then OS.Process.success else OS.Process.failure)
'''
test=test.replace('CASES','['+','.join(json.dumps(n)for n in json.loads((p/'attribute-cases.json').read_text()))+']')
(p/'attribute-probe.sml').write_text(test)
with(p/'attribute-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'lexer.sml'),str(p/'attribute-observe-kernel.sml'),str(p/'attribute-probe.sml'),'-o',str(p/'attribute-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'attribute-probe.log').open('w')as log:r=subprocess.run(['bin/runevm',str(p/'attribute-probe.rbc')],stdout=log,stderr=subprocess.STDOUT)
print((p/'attribute-probe.log').read_text())
raise SystemExit(r.returncode)
