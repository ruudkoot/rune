from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent
base=(p/'make-actions-probe.py').read_text()
start=base.index('parts=');end=base.index("(p/'actions-kernel.sml')")
ns={};exec(base[start:end],{},ns)
parts=ns['parts'][:-2]+['codegen-builders.sml','codegen.sml','driver.sml']
(p/'end-to-end-kernel.sml').write_text(''.join((p/f).read_text()for f in parts)+'\nend\n')
probe=r"""fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor CodegenProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D) structure L=BenchLazy structure F=K.F
 fun one name=
  let val root="tests/out/benchmarks/nofib-happy-originals/"
      val(warnings,output)=K.generate(read(root^"grammar-data/"^name^".input"))
      val expectedWarnings=read(root^"end-to-end-data/"^name^"/stderr")
      val _=if String.implode(F.toList warnings)=expectedWarnings then()
          else raise Fail(label^" "^name^": warnings differ")
      val expected=read(root^"codegen-data/"^name^".reference")
      fun loop index chars=case D.force chars of F.Nil=>
            if index=String.size expected then index else raise Fail("short output at "^Int.toString index)
         |F.Cons(value,rest)=>if index>=String.size expected then raise Fail("long output at "^Int.toString index)
            else if D.force value=String.sub(expected,index)then loop(index+1)rest
            else raise Fail("different output at "^Int.toString index^" expected "^Int.toString(Char.ord(String.sub(expected,index)))^" got "^Int.toString(Char.ord(D.force value)))
      val count=(loop 0 output handle Fail message=>
          let val f=TextIO.openOut(root^"codegen-data/"^name^"-"^label^".actual")
              fun write chars=case D.force chars of F.Nil=>()|F.Cons(value,rest)=>
                   (TextIO.output1(f,D.force value);write rest)
          in write output;TextIO.closeOut f;raise Fail(label^" "^name^": "^message)end)
  in print("PASS "^label^" "^name^" "^Int.toString count^" bytes\n")end
 val _=List.app one CASES
end
structure NeedCodegen=CodegenProbeFn(structure D=BenchNeed val label="need")
structure StrictCodegen=CodegenProbeFn(structure D=BenchStrict val label="strict")
"""
import json
cases=json.loads((p/'lr0-cases.json').read_text())
# Smaller grammars fail quickly; default exercises the complete source input.
names=[r['name']for r in cases if r['name']!='default']+['default']
probe=probe.replace('CASES','['+','.join(json.dumps(n)for n in names)+']')
(p/'end-to-end-probe.sml').write_text(probe)
with(p/'end-to-end-build.log').open('w')as log:
 subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'set.sml'),str(p/'lexer.sml'),str(p/'end-to-end-kernel.sml'),str(p/'end-to-end-probe.sml'),'-o',str(p/'end-to-end-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print(len(cases)*2,'complete generated outputs planned',flush=True)
