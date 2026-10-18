from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
kernel=''.join((p/name).read_text()for name in ['types.sml','reductions.sml','parser-actions.sml','parser-runtime.sml','parser-serialize.sml'])+'\nend\n'
(p/'parser-observe-kernel.sml').write_text(kernel)
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor HappyParserProbeFn(structure D:BENCH_SUSPEND val label:string)=
struct
 structure K=BenchHappyFn(D)
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/parser-data/"
       val actual=K.parseJSON(read(root^name^".input"))^"\n"
       val expected=read(root^name^".reference")
   in if actual=expected then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("Happy parser mismatch "^name^" "^label)end
   end
 val _=List.app one CASES
end
structure NeedHappyParser=HappyParserProbeFn(structure D=BenchNeed val label="need")
structure StrictHappyParser=HappyParserProbeFn(structure D=BenchStrict val label="strict")
'''
test=test.replace('CASES','['+','.join(json.dumps(n)for n in json.loads((p/'parser-cases.json').read_text()))+']')
(p/'parser-probe.sml').write_text(test)
with(p/'parser-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'lexer.sml'),str(p/'parser-observe-kernel.sml'),str(p/'parser-probe.sml'),'-o',str(p/'parser-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'parser-probe.log').open('w')as log:subprocess.run(['bin/runevm',str(p/'parser-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print((p/'parser-probe.log').read_text())
