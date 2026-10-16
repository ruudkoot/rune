from pathlib import Path
import subprocess,json,resource
p=Path(__file__).resolve().parent
texts={
 'rc':'v V plus ground (0, 1)\nr R plus node 1k\nc C node ground 1u 0\n',
 'rl':'v V plus ground (0, 1)\nr R plus node 1k\nl L node ground 1m 0\n',
 'gi':'g G node ground 2m\ni I ground node (0, 1m)\n'}
for name,text in texts.items():(p/(name+'.in')).write_text(text)
cases=[('inverter-small','runtime_files/inverter.in','345','10n','20n','1','0'),
 ('inverter-zero-temperature','runtime_files/inverter.in','345','10n','20n','0','0'),
 ('inverter-background','runtime_files/inverter.in','345','10n','20n','1','0.125'),
 ('inverter-huge-seed','runtime_files/inverter.in',str(2**100+12345),'10n','20n','1','0'),
 ('rc','rc.in','345','1u','3u','1','0'),('rl','rl.in','345','1n','3n','1','0'),('gi','gi.in','345','1n','2n','1','0')]
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
rows=[]
for name,path,seed,dt,end,temp,rbc in cases:
 raw=subprocess.check_output([str(p/'TraceObserver'),path,seed,dt,end,temp,rbc],cwd=p,timeout=60,preexec_fn=cap);(p/(name+'.exacttrace')).write_bytes(raw);rows.append(dict(name=name,args=[path,seed,dt,end,temp,rbc,name+'.exacttrace'],rows=len(raw.splitlines())-1,origin='original inverter fixture'if name.startswith('inverter')else'synthetic constructor/conditional coverage circuit'))
 print('Recorded original small numerical case',name,len(raw.splitlines())-1,flush=True)
(p/'small-cases.json').write_text(json.dumps(rows,indent=2)+'\n')
