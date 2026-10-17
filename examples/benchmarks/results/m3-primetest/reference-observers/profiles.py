from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;lines=(p/'source/primetest.faststdin').read_text().splitlines();profiles=[('suite-smoke',[lines[1]]),('suite-normal',lines[1:4]),('suite-large',lines)]
scope={'__file__':str(p/'independent.py')};exec((p/'independent.py').read_text().split('metadata=[]')[0],scope);rows=[]
for name,numbers in profiles:
 raw=('\n'.join(numbers)+'\n').encode();(p/(name+'.input')).write_bytes(raw)
 original=subprocess.check_output([str(p/'source/original'),'+RTS','-M1g','-RTS'],cwd=p/'source',input=raw,timeout=180)
 observed=subprocess.check_output([str(p/'source/observer'),str(p/(name+'.input'))],cwd=p/'source',timeout=180);(p/(name+'.observe')).write_bytes(observed)
 state=(111,47);expected=[];states=[]
 for i,text in enumerate(numbers):
  result,state,trials,draws=scope['test'](int(text),state);expected.append('Probably prime'if result else'Composite');states.append(dict(index=i,n=text,passed=result,trials=trials,draws=draws,after=scope['peek'](state)))
 assert original==''.join(expected).encode()
 assert observed.decode().splitlines()[1:]==[f'{r["index"]} {r["n"]} {int(r["passed"])} '+' '.join(map(str,r['after']))for r in states]
 (p/(name+'.expected')).write_bytes(original+b'\n')
 rows.append(dict(profile=name,candidates=len(numbers),expected=original.decode(),states=states))
(p/'profile-metadata.json').write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(rows,indent=2))
for mode in ['lazy','strict']:assert(p/('small-'+mode+'.log')).read_text()=='Probably prime\n'
