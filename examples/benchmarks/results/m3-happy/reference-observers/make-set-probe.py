from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
cases=json.loads((p/'set-cases.json').read_text())if(p/'set-cases.json').exists()else[]
if not cases:raise SystemExit('wait for original set observer')
text=r'''structure S=BenchHappySetFn(type item=int val compare=Int.compare)
fun array xs="["^String.concatWith","xs^"]"
fun decimal n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
fun shape S.Tip="[0]"
 |shape(S.Bin(n,x,l,r))=array[decimal n,decimal x,shape l,shape r]
fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
fun one(index,xs,ys,m)=
 let val a=S.fromList(fn()=>xs)val b=S.fromList(fn()=>ys)
     val trees=[a,b,S.union a b,S.difference a b,S.filter(fn n=>n mod m<>0)a]
     val _=List.app(fn t=>ignore(S.validate(BenchLazy.force t)))trees
     val streamed=S.fromStream(S.streamFromList xs)
     val _=if shape(BenchLazy.force streamed)=shape(BenchLazy.force a)then()else raise Fail"streamed set shape mismatch"
     val actual=String.concat(List.map(fn t=>shape(BenchLazy.force t)^"\n")trees)
     val expected=read("tests/out/benchmarks/nofib-happy-originals/set-data/"^Int.toString index^".reference")
 in if actual=expected then print("PASS set "^Int.toString index^"\n")
    else let val f=TextIO.openOut("tests/out/benchmarks/nofib-happy-originals/set-data/"^Int.toString index^".actual")
         in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"set shape mismatch"end end
val _=List.app one CASES
'''
def sml(xs):return '['+','.join('~'+str(-x)if x<0 else str(x)for x in xs)+']'
text=text.replace('CASES','['+','.join('('+str(i)+','+sml(xs)+','+sml(ys)+','+str(m)+')'for i,(xs,ys,m)in enumerate(cases))+']')
(p/'set-probe.sml').write_text(text)
with(p/'set-probe-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml',str(p/'set.sml'),str(p/'set-probe.sml'),'-o',str(p/'set-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'set-probe.log').open('w')as log:subprocess.run(['bin/runevm',str(p/'set-probe.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print(len(cases)*5,'full set shapes agree; balance/order/size checks pass')
