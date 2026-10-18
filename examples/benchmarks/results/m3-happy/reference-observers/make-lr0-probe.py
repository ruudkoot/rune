from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
parts=['types.sml','abstract.sml','arrays.sml','utilities.sml','literals.sml','errors.sml','reductions.sml','parser-actions.sml','parser-runtime.sml',
 'attributes-prefix.sml','attributes-reductions.sml','attributes-actions.sml','attributes-runtime.sml','attributes-format.sml','mangler.sml','first.sml','lr0.sml','parser-serialize.sml','grammar-serialize.sml']
(p/'lr0-kernel.sml').write_text(''.join((p/f).read_text()for f in parts)+'\nend\n')
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor LR0ProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 structure L=BenchLazy
 structure F=K.F
 structure C=K.C
 fun item(rule,dot)=K.jsonArray[K.jsonInt rule,K.jsonInt dot]
 fun cjson f values=
   let fun loop values=case L.force values of C.Nil=>[]
         |C.Cons(value,rest)=>f(L.force value)::loop rest
   in K.jsonArray(loop values)end
 fun state(set,gotos)=K.jsonArray[K.jsonSequence item(K.itemsToList set),
      cjson(fn(token,index)=>K.jsonArray[K.jsonInt token,Int.toString(L.force index)])gotos]
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/"
       val g=case K.parse(K.X.input(read(root^"grammar-data/"^name^".input")))1 of
          K.X.Ok ast=>(case K.mangler"input.y"ast of K.Succeeded value=>L.force value|_=>raise Fail"mangler")
         |_=>raise Fail"parser"
       val closures=K.precalcClosure0 g
       val actual=K.jsonSequence(fn n=>K.jsonArray[Int.toString n,K.jsonSequence item(closures n)])(K.nonterminals g)^"\n"
       val expected=read(root^"lr0-data/"^name^"-closures.reference")
       val _=if actual=expected then print("PASS "^label^" "^name^" closures\n")
             else raise Fail("LR0 closures mismatch "^name)
       val states=K.genLR0items g closures
       val actual=cjson state states^"\n"
       val expected=read(root^"lr0-data/"^name^"-states.reference")
   in if actual=expected then print("PASS "^label^" "^name^" states\n")
      else let val f=TextIO.openOut(root^"lr0-data/"^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("LR0 states mismatch "^name)end end
 val _=List.app one CASES
end
structure NeedLR0=LR0ProbeFn(structure D=BenchNeed val label="need")
structure StrictLR0=LR0ProbeFn(structure D=BenchStrict val label="strict")
'''
cases=json.loads((p/'lr0-cases.json').read_text())
test=test.replace('CASES','['+','.join(json.dumps(r['name'])for r in cases)+']')
(p/'lr0-probe.sml').write_text(test)
with(p/'lr0-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'set.sml'),str(p/'lexer.sml'),str(p/'lr0-kernel.sml'),str(p/'lr0-probe.sml'),'-o',str(p/'lr0-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print(len(cases)*4,'complete LR0 closure/state observations planned',flush=True)
