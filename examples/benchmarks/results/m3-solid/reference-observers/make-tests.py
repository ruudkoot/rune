from pathlib import Path
import shutil
p=Path(__file__).resolve().parent;root=Path.cwd();data=p/'data';data.mkdir(exist_ok=True)
for file in ['scene.input','areas.reference']:shutil.copy(p/file,data/file)
for file in p.glob('shape-*.reference'):shutil.copy(file,data/file.name)
lines=['structure SolidTests=struct',' structure N=BenchSolidFn(BenchNeed)',' structure E=BenchSolidFn(BenchStrict)',' structure NC=BenchSolidCheckFn(N)',' structure EC=BenchSolidCheckFn(E)',' structure L=BenchLazy',' fun check name f=T.check("solid/"^name,f)',' fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end',' val scene=read"scene.input"']
for row in(p/'repaired-areas.reference').read_text().splitlines():
 depth,_,count=row.split()
 for v in ['N','E']:
  lines.append(' val _=check"original-area/'+v+'/'+depth+'"(fn()=>Real.==('+v+'.evaluate scene '+depth+'*Real.fromInt '+str(4**int(depth))+',Real.fromInt '+count+'))')
  if int(depth)<=9:lines.append(' val _=check"original-shape/'+v+'/'+depth+'"(fn()=>'+v+'.shape('+v+'.solution scene '+depth+')^"\\n"=read"shape-'+depth+'.reference")')
for row in(p/'controls.reference').read_text().splitlines():
 fields=row.split()
 if fields[0]=='table':
  _,op,a,b,wanted=fields
  for v in ['N','E']:lines.append(' val _=check"table/'+v+'/'+op+'/'+a+'/'+b+'"(fn()=>'+v+'.combine '+a+' '+v+'.'+{'union':'Union','intersect':'Intersection','diff':'Difference'}[op]+' '+b+'='+wanted+')')
 elif fields[0]=='area':
  _,name,depth,wanted=fields
  for v in ['N','E']:
   first=v+'.primitive('+v+'.circle 0.5 0.5 0.5 0)'
   last=v+'.primitive('+v+'.circle 0.25 0.25 0.25 1)'
   tree=first if name=='circle'else v+'.full()'if name=='full'else v+'.empty()'if name=='empty'else v+'.composed('+first+')'+v+'.'+{'union':'Union','intersect':'Intersection','diff':'Difference'}[name]+'('+last+')'
   lines.append(' val _=check"synthetic-area/'+v+'/'+name+'/'+depth+'"(fn()=>Real.==('+v+'.area('+v+'.build '+depth+' '+v+'.universe('+tree+'))*Real.fromInt '+str(4**int(depth))+',Real.fromInt '+wanted+'))')
for v in ['N','E']:
 lines+=[''' val _=check"union-full-skips-right/'''+v+'''"(fn()=>
 let val poison=L.delay(fn()=>raise Fail"unused right")
 in '''+v+'''.isFull('''+v+'''.merge('''+v+'''.full())'''+v+'''.Union poison)end)''',
''' val _=check"diff-empty-skips-right/'''+v+'''"(fn()=>
 let val poison=L.delay(fn()=>raise Fail"unused right")
 in '''+v+'''.isEmpty('''+v+'''.merge('''+v+'''.empty())'''+v+'''.Difference poison)end)''',
''' val _=check"intersection-checks-right-before-empty-left/'''+v+'''"(fn()=>
 let val poison=L.delay(fn()=>raise Fail"required right")
 in (('''+v+'''.isEmpty('''+v+'''.merge('''+v+'''.empty())'''+v+'''.Intersection poison);false)
    handle Fail text=>text="required right")end)''',
''' val _=check"point-classification-does-not-boolean-shortcut/'''+v+'''"(fn()=>
 let val poison=L.delay(fn()=>raise Fail"required classification")
     val tree='''+v+'''.composed('''+v+'''.full())'''+v+'''.Union poison
 in (('''+v+'''.classify('''+v+'''.point 0.0 0.0)tree;false)
    handle Fail text=>text="required classification")end)''',
''' val _=check"depth-cutoff-still-demands-simple-test/'''+v+'''"(fn()=>
 let val poison=L.delay(fn()=>raise Fail"required simple")
 in ((L.force('''+v+'''.build 0 '''+v+'''.universe poison);false)
    handle Fail text=>text="required simple")end)''',
''' val _=check"parse-ignores-declared-primitive-count/'''+v+'''"(fn()=>'''+v+'''.isFull('''+v+'''.parse"1\\nf\\n999999\\n"))''',
''' val _=check"source-line-classification-grouping/'''+v+'''"(fn()=>'''+v+'''.classifyPrimitive('''+v+'''.line 0.0 1.0 0.5 0)('''+v+'''.point 0.0 1.0)=1)''']
lines+=[''' val _=check"empty-area-skips-cell"(fn()=>
 let val poison=BenchNeed.delay(fn()=>raise Fail"unused rectangle")
 in Real.==(N.leafArea poison(N.empty()),0.0)end)''',
''' val _=check"simple-full-shape-skips-midpoint"(fn()=>
 let val poison=BenchNeed.delay(fn()=>raise Fail"unused rectangle")
 in N.shape(N.build 0 poison(N.full()))="F"end)''',
''' val _=check"strict-finite-coordinates"(fn()=>
 let val point=E.point 0.25 0.5 val(x,y)=E.coordinates point
 in Real.==(x,0.25)andalso Real.==(y,0.5)end)''',
''' val _=check"zero-repetitions"(fn()=>NC.run["0","3","scene.input","areas.reference"]="0:0:0")''',
''' structure Bad=BenchSolidCheckFn(struct fun evaluate(_:string)(_:int)=0.0 end)
 val _=check"reject-incorrect-area"(fn()=>
 ((Bad.run["1","3","scene.input","areas.reference"];false)
    handle Fail text=>String.isPrefix"incorrect result:"text))''','end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+[str(p/(x+'.sml'))for x in ['kernel','check','tests']]+['tests/basis/finish.sml']
(p/'sources.txt').write_text(''.join(str(root/x)+'\n'for x in sources))
(p/'data-list').write_text(''.join(file.name+'\n'for file in sorted(data.iterdir())if file.is_file()))
print('Generated',sum('val _=check'in x for x in lines),'corrected-original/geometry/control assertions')
