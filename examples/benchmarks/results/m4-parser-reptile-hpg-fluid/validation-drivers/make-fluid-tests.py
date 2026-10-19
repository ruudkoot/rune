from pathlib import Path
import shutil,re
root=Path.cwd();tests=root/'tests/benchmarks';p=root/'tests/out/benchmarks/nofib-fluid-originals';d=tests/'data/nofib-fluid';d.mkdir(exist_ok=True)
for name in ['sparse.reference','ordering.reference','numeric.reference','float-show.reference',
             'mesh-input.reference','mesh-order.reference','mesh-factor.reference','mesh-solution.reference',
             'fluid-output.reference','fluid-monitor.reference','fluid-two-steps.reference',
             'fluid-two-steps-monitor.reference','fluid-tolerance-stop.reference']:
 shutil.copyfile(p/name,d/name)
(d/'source/runtime_files').mkdir(parents=True,exist_ok=True)
shutil.copyfile(p/'source/fluid.stdin',d/'source/fluid.stdin')
shutil.copyfile(p/'source/runtime_files/chan8.dat',d/'source/runtime_files/chan8.dat')
(d/'.gitattributes').write_text('# Exact original-language observations and input fixtures.\n** -whitespace\n')
(d/'FILES').write_text('\n'.join(sorted(str(f.relative_to(root))for f in d.rglob('*')if f.is_file()and f.name!='FILES'))+'\n')
def relocate(s):
 return s.replace('tests/out/benchmarks/nofib-fluid-originals/','tests/benchmarks/data/nofib-fluid/')
parts=[]
s=(p/'sparse-probe.sml').read_text()
a=s.index('   in if actual=expected then');b=s.index('\n fun eq a b=',a)
s=s[:a]+'''   in BenchApplicationTestIO.compare("nofib-fluid/sparse/"^label^"/"^Int.toString(!index),expected,actual);index:= !index+1 end
'''+s[b:]
s=s.replace('functor SparseTests(D:BENCH_SUSPEND)=struct','functor NofibFluidSparseTestsFn(structure D:BENCH_SUSPEND val label:string)=struct')
s=s.replace('structure A=SparseTests(BenchNeed)','structure NeedSparse=NofibFluidSparseTestsFn(structure D=BenchNeed val label="lazy")').replace('structure B=SparseTests(BenchStrict)','structure StrictSparse=NofibFluidSparseTestsFn(structure D=BenchStrict val label="strict")')
parts.append(relocate(s))
s=(p/'numeric-probe.sml').read_text()
a=s.index('     val _=ListPair.appEq');b=s.index('\n fun list values=',a)
s=s[:a]+'''     val _=ListPair.appEq(fn(a,b)=>
       (T.check("nofib-fluid/"^label^"/binary32/"^name^"/"^Int.toString(!count),
          fn()=>Real.==(a,b)andalso Real.signBit a=Real.signBit b);count:= !count+1))(actual,expected)
   in()end
'''+s[b:]
s=s.replace('val _=print("PASS all "^Int.toString(!count)^" source binary32 observations\\n")',
            'val _=T.check("nofib-fluid/"^label^"/binary32-observation-count",fn()=> !count=480)')
s=s.replace('functor NumericTests(D:BENCH_SUSPEND)=struct','functor NofibFluidNumericTestsFn(structure D:BENCH_SUSPEND val label:string)=struct')
s=s.replace('structure Need=NumericTests(BenchNeed)','structure NeedNumeric=NofibFluidNumericTestsFn(structure D=BenchNeed val label="lazy")').replace('structure Strict=NumericTests(BenchStrict)','structure StrictNumeric=NofibFluidNumericTestsFn(structure D=BenchStrict val label="strict")')
parts.append(relocate(s))
s=(p/'ordering-probe.sml').read_text()
a=s.index('   in if actual=expected then');b=s.index('\n val cases=',a)
s=s[:a]+'''   in BenchApplicationTestIO.compare("nofib-fluid/"^label^"/ordering/"^Int.toString index,expected,actual)end
'''+s[b:]
s=s.replace('functor OrderingTests(D:BENCH_SUSPEND)=struct','functor NofibFluidOrderingTestsFn(structure D:BENCH_SUSPEND val label:string)=struct')
s=s.replace('structure A=OrderingTests(BenchNeed)','structure NeedOrdering=NofibFluidOrderingTestsFn(structure D=BenchNeed val label="lazy")').replace('structure B=OrderingTests(BenchStrict)','structure StrictOrdering=NofibFluidOrderingTestsFn(structure D=BenchStrict val label="strict")')
parts.append(relocate(s))
s=(p/'mesh-probe.sml').read_text()
s=s.replace('fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end\n','')
s=re.sub(r'\bread\b','BenchApplicationTestIO.read',s)
a=s.index('     in if actual^"\\n"=expected then');b=s.index('\n val header=',a)
s=s[:a]+'''     in BenchApplicationTestIO.compare("nofib-fluid/"^label^"/"^name,expected,actual^"\\n")end
'''+s[b:]
a=s.index(' val _=if file=');b=s.index('\n val mesh:',a)
condition=s[a:b];condition=condition[condition.index('if ')+3:condition.index('   then print')]
s=s[:a]+' val _=T.check("nofib-fluid/"^label^"/configuration",fn()=>'+condition.strip()+')\n'+s[b:]
s=s.replace('functor MeshTests(D:BENCH_SUSPEND)=struct','functor NofibFluidMeshTestsFn(structure D:BENCH_SUSPEND val label:string)=struct')
s=s.replace('structure Need=MeshTests(BenchNeed)','structure NeedMesh=NofibFluidMeshTestsFn(structure D=BenchNeed val label="lazy")').replace('structure Strict=MeshTests(BenchStrict)','structure StrictMesh=NofibFluidMeshTestsFn(structure D=BenchStrict val label="strict")')
parts.append(relocate(s))
s=(p/'full-probe.sml').read_text()
s=s.replace('fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end\n','')
s=re.sub(r'\bread\b','BenchApplicationTestIO.read',s)
a=s.index('   in if actual=expected then');b=s.index('\n val _=List.app check',a)
s=s[:a]+'''   in BenchApplicationTestIO.compare("nofib-fluid/"^label^"/complete/"^name,expected,actual)end
'''+s[b:]
s=s.replace('functor FullTests(D:BENCH_SUSPEND)=struct','functor NofibFluidFullTestsFn(structure D:BENCH_SUSPEND val label:string)=struct')
s=s.replace('structure Need=FullTests(BenchNeed)','structure NeedFull=NofibFluidFullTestsFn(structure D=BenchNeed val label="lazy")').replace('structure Strict=FullTests(BenchStrict)','structure StrictFull=NofibFluidFullTestsFn(structure D=BenchStrict val label="strict")')
parts.append(relocate(s))
s=(p/'float-show-probe.sml').read_text()
a=s.index('   in if actual=expected then');b=s.index('\n val count=',a)
s=s[:a]+'''   in T.check("nofib-fluid/float-show/"^W.toString word,fn()=>actual=expected);loop(n+1)end
'''+s[b:]
s=s.replace('val _=if count=10015 then print"PASS 10015 exact GHC Float Show observations\\n"else raise Fail"oracle count"',
            'val _=T.check("nofib-fluid/float-show/observation-count",fn()=>count=10015)')
parts.append(relocate(s))
(tests/'nofib-fluid-tests.sml').write_text('\n'.join(parts))
