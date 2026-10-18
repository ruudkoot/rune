from pathlib import Path
import subprocess,resource,json,re,struct
p=Path(__file__).resolve().parent
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for n in [1,20,100]:
 r=subprocess.run([str(p/'source/original'),str(-n),'+RTS','-M512m','-RTS'],capture_output=True,timeout=600,preexec_fn=cap)
 (p/('report-'+str(n)+'.reference')).write_bytes(r.stdout)
 (p/('report-'+str(n)+'.stderr')).write_bytes(r.stderr)
 r.check_returncode()
 text=r.stdout.decode();lines=text.splitlines()
 headers=['"RESULT "','"U"','"V"','"R"','"Z"','"Alpha"','"S"','"Rho"','"P"','"Q"','"epsilon"','theta']
 for header in headers:assert header in lines,header
 assert lines[-1]=='done'
 arrays=[line for line in lines if line.startswith('array ')]
 assert len(arrays)==11
 observed=[]
 for line in arrays:
  observed +=[(tuple(map(int,match[:2])),float(match[2]))for match in re.findall(r'\(\((\d+),(\d+)\),([-+0-9.eE]+)\)',line)]
 expected=[]
 for line in(p/('state-'+str(n)+'.reference')).read_text().splitlines():
  cols=line.split('\t')
  if cols[0].startswith('('):
   expected.append((tuple(map(int,re.findall(r'\d+',cols[0]))),struct.unpack('>d',bytes.fromhex(cols[1].zfill(16)))[0]))
 assert len(observed)==len(expected)
 assert all(a==b and struct.pack('>d',x)==struct.pack('>d',y)for(a,x),(b,y)in zip(observed,expected))
 records.append(dict(steps=n,bytes=len(r.stdout),arrays=len(arrays),cells=len(expected),exit=r.returncode))
 print(records[-1],flush=True)
(p/'report-source-validation.json').write_text(json.dumps(records,indent=2)+'\n')
