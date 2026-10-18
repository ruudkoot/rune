from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
js=(p/'parser-serialize.sml').read_text().split(' fun jsonText')[0]
tail=r''' fun literalJSON mode input=
   let val result=if mode="string"then readString(X.text input)else readCharacter(X.text input)
   in case result of NONE=>jsonArray[jsonQuote"none"]
    |SOME(value,rest)=>jsonArray[jsonQuote"ok",jsonQuote(if mode="string"then showString value else showCharacter value),jsonQuote(X.string rest)]
   end
end
'''
(p/'literal-kernel.sml').write_text((p/'types.sml').read_text()+(p/'literals.sml').read_text()+js+tail)
cases=json.loads((p/'literal-cases.json').read_text())
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor LiteralProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 fun one(name,mode)=
   let val root="tests/out/benchmarks/nofib-happy-originals/literal-data/"
       val actual=K.literalJSON mode(read(root^name^".input"))^"\n"
   in if actual=read(root^name^".reference")then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("literal mismatch "^name)end end
 val _=List.app one CASES
end
structure NeedLiterals=LiteralProbeFn(structure D=BenchNeed val label="need")
structure StrictLiterals=LiteralProbeFn(structure D=BenchStrict val label="strict")
'''
test=test.replace('CASES','['+','.join('('+json.dumps(r['name'])+','+json.dumps(r['mode'])+')'for r in cases)+']')
(p/'literal-probe.sml').write_text(test)
with(p/'literal-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'lexer.sml'),str(p/'literal-kernel.sml'),str(p/'literal-probe.sml'),'-o',str(p/'literal-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'literal-probe.log').open('w')as log:subprocess.run(['bin/runevm',str(p/'literal-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print('PASS',2*len(cases),'literal read/show comparisons')
