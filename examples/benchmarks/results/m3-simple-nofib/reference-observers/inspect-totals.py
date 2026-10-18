from pathlib import Path
import subprocess,resource,json
p=Path(__file__).resolve().parent;root=Path.cwd();d=p/'total-diagnostics';d.mkdir(exist_ok=True)
probe=r'''structure K=BenchSimpleNofibFn(val strict=false val gridMax=100)
fun bits x=
 let val v=PackReal64Big.toBytes x
 in String.concat(List.tabulate(8,fn i=>let val h=Word8.fmt StringCvt.HEX(Word8Vector.sub(v,i))
     in if String.size h=1 then"0"^h else h end))end
val(ts,state)=K.compute 20
val(_,refs)=let val C=BenchSimpleReference.read"normal.reference"
  in case C of _::_::_::_::rest=>((),rest)|_=>raise Fail"reference"end
fun loop _ [] []=()
 |loop i(t::ts)(r::rs)=
   let val actual=BenchLazy.force t val expected=BenchSimpleReference.decode r
   in print("TOTAL\t"^Int.toString i^"\t"^bits actual^"\t"^bits expected^"\t"^r^"\n");
      loop(i+1)ts rs end
 |loop _ _ _=raise Fail"totals count"
val _=loop 0 ts refs
val _=List.app(fn(name,a)=>
 let val total=List.foldl(fn(z,s)=>s+Real.abs(K.A.sub a z))0.0(K.A.positions(K.A.bounds a))
 in print("ABS\t"^name^"\t"^bits total^"\n")end)(K.arrays state)
'''
(d/'probe.sml').write_text(probe)
files=[root/'examples/benchmarks/shared/input.sml',root/'examples/benchmarks/shared/lazy.sml',p/'arrays.sml',p/'kernel.sml',p/'check.sml',d/'probe.sml']
def cap():resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
records=[]
for host in ['smlnj32','smlnj-dev','smlnj-legacy']:
 work=d/host;work.mkdir(exist_ok=True)
 (work/'normal.reference').write_bytes((p/'data/totals-100-20.reference').read_bytes())
 driver='val _=((List.app use ['+','.join(json.dumps(str(f))for f in files)+']; OS.Process.exit OS.Process.success) handle e=>(print("DIAGNOSTIC-FAIL "^General.exnMessage e^"\\n"); OS.Process.exit OS.Process.failure));\n'
 (work/'driver.sml').write_text(driver)
 command=['/home/ruud/.local/rune-hosts/'+host+'/bin/sml','driver.sml']
 with(work/'stdout').open('w')as out,(work/'stderr').open('w')as err:r=subprocess.run(command,cwd=work,stdout=out,stderr=err,timeout=600,preexec_fn=cap)
 records.append(dict(host=host,exit=r.returncode,limit_bytes=4*1024**3,timeout_seconds=600));print(records[-1],flush=True)
(d/'exits.json').write_text(json.dumps(records,indent=2)+'\n')
