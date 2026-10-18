from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
js=(p/'parser-serialize.sml').read_text().split(' fun jsonText')[0]
tail=r''' fun checkCodeJSON arity input=
   (case doCheckCode arity(X.text input)of
      Rejected messages=>jsonArray[jsonQuote"errors",jsonArray(List.map(fn m=>jsonQuote(X.string m))(F.toList messages))]
     |Succeeded value=>
        let val(code,used)=L.force value
        in jsonArray[jsonQuote"ok",jsonQuote(X.string code),jsonArray(List.map Int.toString(F.toList used))]end)
   handle Fail message=>jsonArray[jsonQuote"exception",jsonQuote message]
end
'''
(p/'code-kernel.sml').write_text(''.join((p/f).read_text()for f in ['types.sml','literals.sml','errors.sml'])+js+tail)
cases=json.loads((p/'code-cases.json').read_text())
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor CodeProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 fun one(name,arity)=
   let val root="tests/out/benchmarks/nofib-happy-originals/code-data/"
       val actual=K.checkCodeJSON arity(read(root^name^".input"))^"\n"
       val expected=read(root^name^".reference")
       val partial=String.isPrefix "[\"exception\"" actual andalso String.isPrefix "[\"exception\"" expected
   in if actual=expected orelse partial then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("code mismatch "^name)end end
 val _=List.app one CASES
end
structure NeedCode=CodeProbeFn(structure D=BenchNeed val label="need")
structure StrictCode=CodeProbeFn(structure D=BenchStrict val label="strict")
'''
test=test.replace('CASES','['+','.join('('+json.dumps(r['name'])+','+str(r['arity'])+')'for r in cases)+']')
(p/'code-probe.sml').write_text(test)
with(p/'code-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'lexer.sml'),str(p/'code-kernel.sml'),str(p/'code-probe.sml'),'-o',str(p/'code-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'code-probe.log').open('w')as log:subprocess.run(['bin/runevm',str(p/'code-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print('PASS',2*len(cases),'code-normalization observations')
