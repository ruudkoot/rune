from pathlib import Path
import subprocess
root=Path.cwd();p=Path(__file__).resolve().parent
s=(p/'kernel.sml').read_text();assert s.endswith('end\n')
s=s[:-4]+r'''
 fun dumpToken token=case token of NUMB value=>arr[quote"F_NUMB",jsonText value]
   |NAME value=>arr[quote"F_NAME",jsonText value]|SYMB value=>arr[quote"F_SYMB",jsonText value]
   |STR value=>arr[quote"F_STR",jsonText value]|PRAG value=>arr[quote"F_PRAG",jsonText value]
   |ERR value=>arr[quote"F_ERR",jsonText value]|LAYOUT=>arr[quote"C_LAYOUT"]
 fun dumpTokens tokens=case L.force tokens of CEmpty=>arr[quote"[]"]
   |CNext(value,rest)=>arr[quote"(:)",dumpToken(L.force value),dumpTokens rest]
end
'''
(p/'kernel.sml').write_text(s)
(p/'parse-pilot.sml').write_text(r'''
functor ParsePilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name stage actual=
   if actual^"\n"=read(name^"-"^stage^".reference")then print("PASS "^name^"/"^stage^"\n")
   else let val f=TextIO.openOut(name^"-"^stage^"-actual.json")
        in TextIO.output(f,actual);TextIO.closeOut f;raise Fail(name^"/"^stage)end
 fun run name=
   let val input=K.text(read(name^".input"))
       val tokens=K.lexer input
       val raw=K.parse(K.dropPragma tokens)
       val _=check name"tokens"(K.dumpTokens tokens)
       val _=check name"parse"(K.dumpProgram raw)
       val prepared=K.label(K.use(K.sorted raw)))
   in()end
 val _=List.app run["simple","fib","fibsum","tailtest","setreset","flipflop","wave4","wavestream","hamming","gamma","fft"]
end
structure NeedParse=ParsePilotFn(BenchNeed)
structure StrictParse=ParsePilotFn(BenchStrict)
'''.replace('K.label(K.use(K.sorted raw)))','K.label(K.use(K.sorted raw))'))
files=[root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'kernel.sml',p/'parse-pilot.sml']
with(p/'parse-pilot-build.log').open('w')as log:subprocess.run(['bin/rune','--lint',*map(str,files),'-o',str(p/'parse-pilot.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'parse-pilot.log').open('w')as log:subprocess.run([str(root/'bin/runevm'),'parse-pilot.rbc'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
print((p/'parse-pilot.log').read_text())
