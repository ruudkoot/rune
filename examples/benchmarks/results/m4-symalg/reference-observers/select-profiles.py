from pathlib import Path
import subprocess,json,resource
p=Path(__file__).resolve().parent
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,stem in [('selected-normal','fast'),('selected-large','slow')]:
 original=p/'source'/('symalg.'+stem+'stdin')
 script='\n'.join(original.read_text().splitlines()[:10]+['exit'])+'\n'
 (p/(profile+'.stdin')).write_text(script)
 for suffix,program in [('stdout',p/'source/original'),('full-output',p/'full-observer-source/full-observer')]:
  r=subprocess.run([str(program)],input=script.encode(),capture_output=True,check=True,timeout=120,preexec_fn=cap)
  (p/(profile+'.'+suffix)).write_bytes(r.stdout)
 precision=script.splitlines()[0].split('=')[1].strip()
 full=(p/(profile+'.full-output')).read_text()
 prefix='-> Eval\t'+precision+'\nSet\t$prec to '+precision+'\n'
 assert full.startswith(prefix)and full.endswith('-> ')
 numbers=[precision,precision]
 for line in full[len(prefix):-3].splitlines():
  assert line.startswith('-> ');numbers.append(line[3:])
 assert len(numbers)==11
 (p/(profile+'.numbers.reference')).write_text('\n'.join(numbers)+'\n')
 records.append(dict(profile=profile,precision=int(precision),sqrt_commands=9,source_commands=261,source_input=original.name,selection='first original cycle; retain precision; deterministic exit'))
 print(records[-1],flush=True)
(p/'selected-profiles.json').write_text(json.dumps(records,indent=2)+'\n')
