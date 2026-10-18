from pathlib import Path
import json,shutil
p=Path(__file__).resolve().parent;root=Path.cwd()
lines=['structure CompLabTests=struct',' structure N=BenchCompLabFn(BenchNeed)',' structure E=BenchCompLabFn(BenchStrict)',' structure NC=BenchCompLabCheckFn(N)',' structure EC=BenchCompLabCheckFn(E)',' structure L=BenchLazy',' fun check name f=T.check("comp-lab/"^name,f)',' fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end']
for row in json.loads((p/'case-results.json').read_text()):
 key=row['key'];args=('true'if row['mode']=='zift'else'false')+' '+str(row['selector'])+' '+str(row['size'])+' '+str(row['threshold'])
 for v in ['N','E']:lines.append(' val _=check"full-original/'+v+'/'+key+'"(fn()=>'+v+'.rendered '+args+'=read"cases/'+key+'.reference")')
for v,policy in [('N','BenchNeed'),('E','BenchStrict')]:
 lines+=[''' val _=check"merge-retains-duplicates/'''+v+'''"(fn()=>
 let val a='''+v+'''.makeTree 2('''+v+'''.F.fromList[1,2])
     val b='''+v+'''.makeTree 2('''+v+'''.F.fromList[2,3])
     val tree='''+v+'''.treeUnion(#2('''+policy+'''.force a))(#2('''+policy+'''.force b))
 in '''+v+'''.F.toList('''+v+'''.flatten tree)=[1,2,2,3]end)''',
''' val _=check"select-leaf-outside-bounds-is-retained/'''+v+'''"(fn()=>
 let val leaf='''+policy+'''.delay(fn()=>'''+v+'''.Leaf('''+policy+'''.delay(fn()=>3)))
 in '''+v+'''.treeMin('''+v+'''.selectTree 100 200 leaf)=3 end)''',
''' val _=check"cropped-object-keeps-global-representative/'''+v+'''"(fn()=>
 let val made='''+v+'''.makeTree 2('''+v+'''.F.fromList[1,2])
     val obj='''+policy+'''.delay(fn()=>'''+v+'''.Set('''+policy+'''.delay(fn()=>1),#2('''+policy+'''.force made)))
     val selected='''+v+'''.selectSet 2 3 obj
 in '''+v+'''.top selected=1 andalso '''+v+'''.setMember selected 2 andalso not('''+v+'''.setMember selected 1)end)''',
''' val _=check"ignored-sandwich-hints/'''+v+'''"(fn()=>
 '''+v+'''.sandwich(fn a=>fn b=>a+b)
    ('''+v+'''.SandArg(3,L.delay(fn()=>raise Fail"left hint")))
    ('''+v+'''.SandArg(4,L.delay(fn()=>raise Fail"right hint")))=7)''',
''' val _=check"plain-map-skips-generator/'''+v+'''"(fn()=>
 let val image='''+v+'''.figure 1
     val field='''+v+'''.pixelFieldSeq('''+v+'''.F.map '''+v+'''.pixelsToRanges image)2('''+v+'''.generator 2 0 0)
     val labels='''+v+'''.fieldLabels field
     val objects='''+v+'''.fieldObjects field
     val gen=L.delay(fn()=>raise Fail"unused generator")
     val result='''+v+'''.mapLabel '''+v+'''.noSift labels 2 gen objects 0
 in List.map(fn row=>List.map '''+v+'''.labelOf('''+v+'''.F.toList row))('''+v+'''.F.toList result)=[[0],[0]]end)''',
''' val _=check"sifting-demands-generator/'''+v+'''"(fn()=>
 let val image='''+v+'''.figure 1
     val field='''+v+'''.pixelFieldSeq('''+v+'''.F.map '''+v+'''.pixelsToRanges image)2('''+v+'''.generator 2 0 0)
     val labels='''+v+'''.fieldLabels field
     val objects='''+v+'''.fieldObjects field
     val gen=L.delay(fn()=>raise Fail"expected generator demand")
 in ((List.map(fn row=>List.map '''+v+'''.labelOf('''+v+'''.F.toList row))
       ('''+v+'''.F.toList('''+v+'''.mapLabel '''+v+'''.sift labels 2 gen objects 0));false)
    handle Fail text=>text="expected generator demand")end)''']
lines+=[''' val _=check"disjoint-border-skips-labels-and-objects"(fn()=>
 let val count=ref 0
     val objects=BenchNeed.delay(fn()=>(count:= !count+1;N.F.Nil))
     fun row start finish=N.F.fromList[N.LabRange(BenchNeed.delay(fn()=>raise Fail"unused label"),
        BenchNeed.delay(fn()=>N.Range(BenchNeed.delay(fn()=>start),BenchNeed.delay(fn()=>finish))))]
     val result=N.unionBorder(row 0 1)(row 2 3)objects
 in !count=0 andalso N.F.length result=0 andalso !count=1 end)''',
''' val _=check"ordered-tree-union-skips-unused-left-subtree"(fn()=>
 let val poison=BenchNeed.delay(fn()=>raise Fail"unused subtree")
     val leaf2=BenchNeed.delay(fn()=>N.Leaf(BenchNeed.delay(fn()=>2)))
     val first=BenchNeed.delay(fn()=>N.Tree(BenchNeed.delay(fn()=>1),poison,leaf2))
     val last=BenchNeed.delay(fn()=>N.Leaf(BenchNeed.delay(fn()=>3)))
 in case BenchNeed.force(N.treeUnion first last)of N.Tree(key,_,_)=>BenchNeed.force key=2|_=>false end)''',
''' val _=check"tree-membership-skips-unused-subtree"(fn()=>
 let val poison=BenchNeed.delay(fn()=>raise Fail"unused subtree")
     val leaf=BenchNeed.delay(fn()=>N.Leaf(BenchNeed.delay(fn()=>3)))
     val tree=BenchNeed.delay(fn()=>N.Tree(BenchNeed.delay(fn()=>2),poison,leaf))
 in N.member tree 3 end)''',
''' val _=check"selection-skips-unused-subtree"(fn()=>
 let val poison=BenchNeed.delay(fn()=>raise Fail"unused subtree")
     val leaf=BenchNeed.delay(fn()=>N.Leaf(BenchNeed.delay(fn()=>3)))
     val tree=BenchNeed.delay(fn()=>N.Tree(BenchNeed.delay(fn()=>2),poison,leaf))
 in N.treeMin(N.selectTree 3 4 tree)=3 end)''',
''' val _=check"memoized-finite-fields"(fn()=>
 let val count=ref 0 val value=BenchNeed.delay(fn()=>(count:= !count+1;7))
     val tree=BenchNeed.delay(fn()=>N.Leaf value)
 in N.treeMin tree=7 andalso N.treeMin tree=7 andalso !count=1 end)''',
''' val _=check"strict-finite-fields"(fn()=>
 let val count=ref 0
     val tree=BenchStrict.delay(fn()=>E.Leaf(BenchStrict.delay(fn()=>(count:= !count+1;7))))
 in !count=1 andalso E.treeMin tree=7 end)''',
''' structure Zero=BenchCompLabCheckFn(struct
 fun rendered(_:bool)(_:int)(_:int)(_:int):string=raise Fail"zero-work renderer"
 fun sumcode(_:string):string=raise Fail"zero-work checksum"
 end)
 val _=check"zero-work-skips-renderer"(fn()=>Zero.run true["0","1","0","cases/3-1-0-zift.reference","ignored"]="0:0")''',
''' val _=check"reject-wrong-complete-state"(fn()=>
 ((NC.run true["1","1","0","cases/0-1-0-zift.reference","ignored"];false)
 handle Fail why=>String.isPrefix"incorrect result:"why))''',
''' val _=check"reject-wrong-source-sumcode"(fn()=>
 ((NC.run true["1","1","0","cases/3-1-0-zift.reference","wrong"];false)
 handle Fail why=>String.isPrefix"incorrect result:"why))''','end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
data=p/'data';shutil.copytree(p/'cases',data/'cases',dirs_exist_ok=True)
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+[str(p/(x+'.sml'))for x in ['figures','kernel','check','tests']]+['tests/basis/finish.sml']
(p/'sources.txt').write_text(''.join(str(root/x)+'\n'for x in sources))
(p/'data-list').write_text(''.join(str(f.relative_to(data))+'\n'for f in sorted(data.rglob('*.reference'))))
print('Generated',sum('val _=check'in x for x in lines),'original/demand/checker assertions')
