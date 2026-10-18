from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
parts=['types.sml','abstract.sml','arrays.sml','utilities.sml','literals.sml','errors.sml','reductions.sml','parser-actions.sml','parser-runtime.sml',
 'attributes-prefix.sml','attributes-reductions.sml','attributes-actions.sml','attributes-runtime.sml','attributes-format.sml','mangler.sml','first.sml','parser-serialize.sml','grammar-serialize.sml']
(p/'first-kernel.sml').write_text(''.join((p/f).read_text()for f in parts)+'\nend\n')
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor FirstProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 structure F=K.F
 structure L=BenchLazy
 exception Unexpected
 fun one(name,queries)=
   let val root="tests/out/benchmarks/nofib-happy-originals/"
       val g=case K.parse(K.X.input(read(root^"grammar-data/"^name^".input")))1 of
          K.X.Ok ast=>(case K.mangler"input.y"ast of K.Succeeded value=>L.force value|_=>raise Fail"mangler")
         |_=>raise Fail"parser"
       val first=K.mkFirst g
       fun line query=K.jsonInts(K.namesFromSet(first(F.fromList query)))^"\n"
       val actual=String.concat(List.map line queries)
       val expected=read(root^"first-data/"^name^".reference")
   in if actual=expected then print("PASS "^label^" "^name^" "^Int.toString(List.length queries)^"\n")
      else let val f=TextIO.openOut(root^"first-data/"^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("FIRST mismatch "^name)end end
 val _=List.app one CASES
 val noNext=K.mkClosure(fn value=>fn _=>value=17)(fn _=>raise Unexpected)17
 val _=if noNext=17 then print("PASS "^label^" closure-unused-next\n")else raise Fail"closure"
 val firstOnly=K.joinSymSets(fn n=>if n=1 then K.NameSet.singleton 7 else raise Unexpected)(F.fromList[1,2])
 val _=if K.NameSet.member 7 firstOnly then print("PASS "^label^" first-unused-suffix\n")else raise Fail"suffix"
 val empty=K.joinSymSets(fn _=>raise Unexpected)(F.empty())
 val _=if K.NameSet.member 0 empty then print("PASS "^label^" empty-first-skips-function\n")else raise Fail"empty"
end
structure NeedFirst=FirstProbeFn(structure D=BenchNeed val label="need")
structure StrictFirst=FirstProbeFn(structure D=BenchStrict val label="strict")
'''
cases=json.loads((p/'first-cases.json').read_text())
def sl(xs):return '['+','.join(str(x)for x in xs)+']'
test=test.replace('CASES','['+','.join('('+json.dumps(r['name'])+',['+','.join(sl(q)for q in r['queries'])+'])'for r in cases)+']')
(p/'first-probe.sml').write_text(test)
with(p/'first-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'set.sml'),str(p/'lexer.sml'),str(p/'first-kernel.sml'),str(p/'first-probe.sml'),'-o',str(p/'first-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print(sum(len(r['queries'])for r in cases)*2,'FIRST-set observations planned',flush=True)
