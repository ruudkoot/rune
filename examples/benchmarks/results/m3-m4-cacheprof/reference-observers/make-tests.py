from pathlib import Path
import json,re,shutil
p=Path(__file__).resolve().parent;root=Path.cwd()
rows=json.loads((p/'case-results.json').read_text())
lines=['structure CacheprofTests=struct',' structure N=BenchCacheprofFn(BenchNeed)',' structure E=BenchCacheprofFn(BenchStrict)',' structure A=BenchCacheprofArch',' fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end',' fun check name f=T.check("cacheprof/"^name,f)']
for row in rows:
 key=row['key'];level=str(row['level'])
 for variant in ['N','E']:
  call=variant+'.rendered '+level+'(read"cases/'+key+'.s")'
  if row['status']=='pass':test=call+'=read"cases/'+key+'.expected"'
  else:
   stderr=(p/'cases'/(key+'.stderr')).read_text()
   category=next(x for x in ['Bad input:','Unhandled instruction set artefact:','Internal error:']if x in stderr)
   test='(('+call+';false)handle Fail why=>String.isSubstring"'+category+'"why)'
  lines.append(' val _=check"'+variant+'/'+key+'"(fn()=>'+test+')')
def effect(match):
 name=match[1];values=match[2].split()
 return 'A.'+name+' '+values[0]if len(values)==1 else'A.'+name+'('+','.join(values)+')'
for i,row in enumerate((p/'original-architecture.reference').read_text().splitlines()):
 opcode,info,nonjump=row.split('\t')
 expected=re.sub(r'(OE_\w+)((?:\s+\d+)+)',effect,info)
 expected=re.sub(r'\b(OI\w*)\b',r'A.\1',expected)
 lines.append(' val _=check"opcode-info/'+opcode+'"(fn()=>List.nth(A.x86info,'+str(i)+')=(A.'+opcode+','+expected+')andalso List.exists(fn x=>x=A.'+opcode+')A.nonJumpyOpcodes='+nonjump.lower()+')')
for label,source,reference in [('fast','real/source/cacheprof.faststdin','source-fast.annotated'),('normal','real/source/cacheprof.stdin','normal.annotated'),('slow','real/source/cacheprof.slowstdin','source-slow.annotated')]:
 for variant in ['N','E']:lines.append(' val _=check"complete-'+label+'/'+variant+'"(fn()=>'+variant+'.rendered 2(read"'+label+'.s")=read"'+reference+'")')
lines+=[''' val _=check"memoized-finite-stage-head"(fn()=>
 let val count=ref 0
     val values=N.F.map(fn x=>(count:= !count+1;x))(N.F.fromList[1,2,3])
     val pending= !count=0
     val first=N.F.nth values 0
     val second=N.F.nth values 0
 in pending andalso first=1 andalso second=1 andalso !count=1 end)''',
''' val _=check"strict-finite-stage-materialization"(fn()=>
 let val count=ref 0
     val values=E.F.map(fn x=>(count:= !count+1;x))(E.F.fromList[1,2,3])
 in !count=3 andalso E.F.nth values 2=3 end)''',
''' val _=check"peephole-label-prefix-skips-tail"(fn()=>
 let val tail=BenchNeed.delay(fn()=>raise Fail"undemanded line tail")
     val values=N.F.cons(BenchNeed.delay(fn()=>N.Label(1,"label:")),tail)
 in case N.F.nth(N.peephole values)0 of N.Label(_,"label:")=>true|_=>false end)''',
''' val _=check"level0-prefix-skips-invalid-later-instruction"(fn()=>N.F.nth(N.output 0"#keep\\nbroken ???\\n")0="#keep\\n")''',
''' val _=check"level2-cc-guard-demands-invalid-later-instruction"(fn()=>((N.F.nth(N.output 2"#keep\\nbroken ???\\n")0;false)handle Fail why=>String.isSubstring"Bad input:"why))''',
'end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
data=p/'data';data.mkdir(exist_ok=True);shutil.copytree(p/'cases',data/'cases',dirs_exist_ok=True)
for label,file in [('fast','cacheprof.faststdin'),('normal','cacheprof.stdin'),('slow','cacheprof.slowstdin')]:shutil.copy(p/'real/source'/file,data/(label+'.s'))
for file in ['source-fast.annotated','normal.annotated','source-slow.annotated']:shutil.copy(p/file,data/file)
sources=['tests/basis/harness.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+[str(p/(x+'.sml'))for x in ['architecture','kernel','tests']]+['tests/basis/finish.sml']
(p/'sources.txt').write_text(''.join(str(root/x)+'\n'for x in sources))
(p/'data-list').write_text(''.join(str(f.relative_to(data))+'\n'for f in sorted(data.rglob('*'))if f.is_file()))
print('Generated',sum('val _=check'in x for x in lines),'independent-original and demand assertions')
