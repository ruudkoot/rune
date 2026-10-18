from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
parts=['types.sml','abstract.sml','arrays.sml','utilities.sml','literals.sml','errors.sml','reductions.sml','parser-actions.sml','parser-runtime.sml']
text=''.join((p/f).read_text()for f in parts)
text+=''.join((p/f).read_text()for f in ['attributes-prefix.sml','attributes-reductions.sml','attributes-actions.sml','attributes-runtime.sml','attributes-format.sml'])
text+=''.join((p/f).read_text()for f in ['mangler.sml','parser-serialize.sml','grammar-serialize.sml'])+'\nend\n'
(p/'grammar-observe-kernel.sml').write_text(text)
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
val failures=ref 0
functor GrammarProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/grammar-data/"
       val actual=K.grammarJSON(read(root^name^".input"))^"\n"
   in if actual=read(root^name^".reference")then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;
              failures:= !failures+1;print("FAIL "^label^" "^name^"\n")end end
 val _=List.app one CASES
end
structure NeedGrammar=GrammarProbeFn(structure D=BenchNeed val label="need")
structure StrictGrammar=GrammarProbeFn(structure D=BenchStrict val label="strict")
val _=OS.Process.exit(if !failures=0 then OS.Process.success else OS.Process.failure)
'''
cases=json.loads((p/'grammar-cases.json').read_text())
test=test.replace('CASES','['+','.join(json.dumps(name)for name in cases)+']')
(p/'grammar-probe.sml').write_text(test)
with(p/'grammar-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'lexer.sml'),str(p/'grammar-observe-kernel.sml'),str(p/'grammar-probe.sml'),'-o',str(p/'grammar-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'grammar-probe.log').open('w')as log:r=subprocess.run(['bin/runevm',str(p/'grammar-probe.rbc')],stdout=log,stderr=subprocess.STDOUT)
print((p/'grammar-probe.log').read_text())
raise SystemExit(r.returncode)
