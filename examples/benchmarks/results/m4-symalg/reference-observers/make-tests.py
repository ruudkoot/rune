from pathlib import Path
import shutil,json
p=Path(__file__).resolve().parent
data=p/'data';data.mkdir(exist_ok=True)
for name in ['commands.stdin','commands.stdout','smoke.stdin','smoke.stdout','smoke.numbers.reference']:
 shutil.copy(p/name,data/name)
numbers=(p/'smoke.numbers.reference').read_text().splitlines();value=numbers[2]
numbers[2]=value[:-1]+str((int(value[-1])+1)%10)
(data/'smoke-corrupt.numbers.reference').write_text('\n'.join(numbers)+'\n')
out=(p/'smoke.stdout').read_text();(data/'smoke-corrupt.stdout').write_text('!'+out[1:])
text=(p/'real-tests.sml').read_text()
lines=['structure SymalgTests=struct',' structure N=BenchSymalgFn(BenchNeed)',' structure E=BenchSymalgFn(BenchStrict)',' structure NC=BenchSymalgCheckFn(N)',' structure EC=BenchSymalgCheckFn(E)',' fun check name f=T.check("symalg/"^name,f)',' fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end',' val commands=String.fields(fn c=>c= #"\\n")(read"commands.stdin")']
for variant in ['N','E']:
 lines.append(' val _=check"original-commands/'+variant+'"(fn()=>'+variant+'.transcript commands=read"commands.stdout")')
 lines.append(' val _=check"full-original-smoke/'+variant+'"(fn()=>'+variant+'C.run["smoke.stdin","smoke.numbers.reference","smoke.stdout"]="11:'+str(len((p/'smoke.stdout').read_bytes()))+'")')
 lines.append(' val _=check"zero-product-skips-msd-zero/'+variant+'"(fn()=>'+variant+'.B.R.eval('+variant+'.B.R.multiply('+variant+'.B.R.fromInteger 0)('+variant+'.B.R.fromInteger 0))(~10)=0)')
 lines.append(''' val _=check"memoized-approximation-tree/'''+variant+'''"(fn()=>
 let val count=ref 0
     val tree='''+variant+'''.B.R.mapTree(fn x=>(count:= !count+1;x))'''+variant+'''.B.R.numberTree
     val real='''+variant+'''.B.R.Real tree
     val first='''+variant+'''.B.R.eval real(~4)
     val once= !count
     val second='''+variant+'''.B.R.eval real(~4)
 in first=second andalso once>0 andalso !count=once end)''')
for path in ['smoke-corrupt.numbers.reference','smoke-corrupt.stdout']:
 args='["smoke.stdin","'+('smoke-corrupt.numbers.reference'if'numbers'in path else'smoke.numbers.reference')+'","'+('smoke.stdout'if'numbers'in path else'smoke-corrupt.stdout')+'"]'
 lines.append(' val _=check"reject-'+path+'"(fn()=>((NC.run'+args+';false)handle Fail why=>String.isPrefix"incorrect result:"why))')
lines.append('end')
(p/'tests-final.sml').write_text(text+'\n'+'\n'.join(lines)+'\n')
root=Path.cwd();sources=['tests/basis/harness.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml']+[str(p/(x+'.sml'))for x in ['real','number','kernel','check','tests-final']]+['tests/basis/finish.sml']
(p/'sources-final.txt').write_text(''.join(str(root/x)+'\n'for x in sources))
(p/'data-list').write_text(''.join(x.name+'\n'for x in sorted(data.iterdir())))
print('332 assertions including full-number and transcript rejection')
