from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
parts=['types.sml','abstract.sml','arrays.sml','utilities.sml','literals.sml','errors.sml','reductions.sml','parser-actions.sml','parser-runtime.sml',
 'attributes-prefix.sml','attributes-reductions.sml','attributes-actions.sml','attributes-runtime.sml','attributes-format.sml','mangler.sml',
 'first.sml','lr0.sml','lr1.sml','lookaheads.sml','parser-serialize.sml','grammar-serialize.sml']
(p/'lookahead-kernel.sml').write_text(''.join((p/f).read_text()for f in parts)+'\nend\n')
test=r'''fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor LookaheadProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 structure L=BenchLazy
 structure F=K.F
 structure C=K.C
 fun item(rule,dot)=K.jsonArray[K.jsonInt rule,K.jsonInt dot]
 fun names set=K.jsonInts(K.namesFromSet set)
 fun cjson f values=
   let fun loop values=case L.force values of C.Nil=>[]
         |C.Cons(value,rest)=>f(L.force value)::loop rest
   in K.jsonArray(loop values)end
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/"
       val g=case K.parse(K.X.input(read(root^"grammar-data/"^name^".input")))1 of
          K.X.Ok ast=>(case K.mangler"input.y"ast of K.Succeeded value=>L.force value|_=>raise Fail"mangler")
         |_=>raise Fail"parser"
       val first=K.mkFirst g
       val states=K.genLR0items g(K.precalcClosure0 g)
       val(spont,prop)=K.propLookaheads g states first
       fun check mode actual=
         let val expected=read(root^"lookahead-data/"^name^"-"^mode^".reference")
         in if actual^"\n"=expected then print("PASS "^label^" "^name^" "^mode^"\n")
            else let val f=TextIO.openOut(root^"lookahead-data/"^name^"-"^mode^"-"^label^".actual")
                 in TextIO.output(f,actual^"\n");TextIO.closeOut f;raise Fail("lookahead mismatch "^name^" "^mode)end end
       val _=check"spontaneous"(cjson(fn(i,key,s)=>K.jsonArray[Int.toString(L.force i),item key,names s])spont)
       val _=check"propagated"(K.jsonSequence(fn(i,edges)=>K.jsonArray[Int.toString i,
           cjson(fn(key,j,target)=>K.jsonArray[item key,Int.toString(L.force j),item target])edges])(K.A.assocs prop))
       val final=K.calcLookaheads(K.cLength states)spont prop
       val _=check"final"(K.jsonSequence(fn(i,values)=>K.jsonArray[Int.toString i,
           cjson(fn(key,s)=>K.jsonArray[item key,names s])values])(K.A.assocs final))
       val merged=K.mergeLookaheadInfo final states
       val _=check"merged"(cjson(fn(values,gotos)=>K.jsonArray[
          cjson(fn(rule,dot,s)=>K.jsonArray[K.jsonInt rule,K.jsonInt dot,names s])values,
          cjson(fn(token,index)=>K.jsonArray[K.jsonInt token,Int.toString(L.force index)])gotos])merged)
   in()end
 val _=List.app one CASES
end
structure NeedLookaheads=LookaheadProbeFn(structure D=BenchNeed val label="need")
structure StrictLookaheads=LookaheadProbeFn(structure D=BenchStrict val label="strict")
'''
cases=json.loads((p/'lookahead-cases.json').read_text())
test=test.replace('CASES','['+','.join(json.dumps(r['name'])for r in cases)+']')
(p/'lookahead-probe.sml').write_text(test)
with(p/'lookahead-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'set.sml'),str(p/'lexer.sml'),str(p/'lookahead-kernel.sml'),str(p/'lookahead-probe.sml'),'-o',str(p/'lookahead-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print(len(cases)*8,'complete lookahead observations planned',flush=True)
