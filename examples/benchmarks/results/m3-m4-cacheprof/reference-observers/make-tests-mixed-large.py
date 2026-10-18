from pathlib import Path
import subprocess,shutil
p=Path(__file__).resolve().parent;root=Path.cwd()
subprocess.run(['python3',str(p/'make-tests.py')],check=True)
data=p/'data';hooks=(p/'gc/source/cacheprof_hooks2_x86.s').read_bytes()
full=(p/'gc/full-reservoir.stdout').read_bytes();assert full.endswith(hooks)
(data/'full.s').write_bytes((p/'real/source/cacheprof.full').read_bytes())
(data/'full.annotated').write_bytes(full[:-len(hooks)])
(data/'hooks.s').write_bytes(hooks)
(data/'raw-fast.reference').write_bytes((p/'source-fast.annotated').read_bytes()+hooks)
extra=[]
for variant in ['N','E']:
 extra+=[' val _=check"full-reservoir-golden/'+variant+'"(fn()=>'+variant+'.rendered 2(read"full.s")=read"full.annotated")']
extra+=[' structure NC=BenchCacheprofCheckFn(N)',' structure EC=BenchCacheprofCheckFn(E)']
for variant in ['N','E']:
 extra+=[' val _=check"raw-driver/'+variant+'"(fn()=>'+variant+'C.runRaw["fast.s","raw-fast.reference","hooks.s"]="11288")',
 ' val _=check"forced-driver/'+variant+'"(fn()=>'+variant+'C.runForced["1","fast.s","source-fast.annotated","hooks.s"]="1:7439")']
extra+=[''' val _=check"reject-corrupted-assembly"(fn()=>
 let val(emit,finish)=NC.consumer"expected"
 in ((emit"incorrect";finish();false)handle Fail why=>String.isPrefix"incorrect result:"why)end)''',
''' val _=check"reject-truncated-assembly"(fn()=>
 let val(emit,finish)=NC.consumer"expected"
 in ((emit"expec";finish();false)handle Fail why=>String.isPrefix"incorrect result:"why)end)''',
''' structure Undemanded=BenchCacheprofCheckFn(struct fun emitOutput(_:int)(_:string)(_:string->unit)=raise Fail"zero-work annotation"end)
 val _=check"zero-work-skips-annotation-and-unused-hook-open"(fn()=>
 Undemanded.runForced["0","fast.s","source-fast.annotated","missing-unopened-hooks.s"]="0:0")''']
text=(p/'tests.sml').read_text();assert text.endswith('end\n')
(p/'tests-final.sml').write_text(text[:-4]+'\n'.join(extra)+'\nend\n')
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+[str(p/(x+'.sml'))for x in ['architecture','kernel','check','tests-final']]+['tests/basis/finish.sml']
(p/'sources-final.txt').write_text(''.join(str(root/x)+'\n'for x in sources))
(p/'data-list').write_text(''.join(str(f.relative_to(data))+'\n'for f in sorted(data.rglob('*'))if f.is_file()))
print('Final824assertions')
