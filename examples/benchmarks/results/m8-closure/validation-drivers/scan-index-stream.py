from pathlib import Path
import subprocess,csv,io,hashlib,json,time,sys
started=time.monotonic();p=Path(sys.argv[1])if len(sys.argv)>1 else Path(__file__).resolve().parent
policy=Path('tests/out/benchmarks/scan-staged-fast.py')
allowed={}
table='examples/benchmarks/validation/hartel-event-state-identities.tsv'
r=subprocess.run(['git','show',':'+table],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
if r.returncode==0:
 for row in csv.DictReader(io.StringIO(r.stdout.decode()),delimiter='\t'):
  assert row['kind']=='reviewed-text-state'and row['bytes']=='14'
  assert row['path'].startswith(('examples/benchmarks/event-','examples/benchmarks/results/m3-hartel-event/reference-observers/cases/','tests/benchmarks/data/event/cases/'))
  allowed[row['path']]=(14,row['sha256'])
names=[v for v in subprocess.check_output(['git','diff','--cached','--name-only','--diff-filter=ACMR','-z']).split(b'\0')if v]
index={}
for entry in subprocess.check_output(['git','ls-files','--stage','-z']).split(b'\0'):
 if not entry:continue
 meta,path=entry.split(b'\t',1);mode,identity,stage=meta.split();assert stage==b'0'
 index[path]=identity
total=0;bad=[];ledger=[]
proc=subprocess.Popen(['git','cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
for raw in names:
 proc.stdin.write(index[raw]+b'\n');proc.stdin.flush()
 header=proc.stdout.readline().split();assert header[0]==index[raw]and header[1]==b'blob'
 length=int(header[2]);name=raw.decode();path=Path(name)
 # Bound working memory: no complete blob is buffered. Stream fingerprints and content policy.
 digest=hashlib.sha256();gitdigest=hashlib.sha1(b'blob '+str(length).encode()+b'\0')
 remaining=length;prefix=b'';has_nul=False;review_data=b''
 while remaining:
  data=proc.stdout.read(min(4*1024**2,remaining));assert data
  if not prefix:prefix=data[:16]
  has_nul=has_nul or b'\0'in data;digest.update(data);gitdigest.update(data);remaining-=len(data)
  if length==14:review_data+=data
 assert proc.stdout.read(1)==b'\n'
 assert gitdigest.hexdigest().encode()==index[raw],name
 sha=digest.hexdigest()
 binary=prefix.startswith((bytes([127])+b'ELF',b'MZ',b'!<arch>'+bytes([10])))or has_nul
 reviewed=(path.suffix=='.state'and name in allowed and(length,sha)==allowed[name]
   and length==14 and review_data[13:]==bytes([10])and all(c in b'xLH'for c in review_data[:13]))
 compiled=(path.suffix in ['.rbc','.o','.hi','.exe','.heap','.state','.cmx','.cmi','.cmo','.a','.cmxa','.cma','.dyn_o','.dyn_hi']
   or any(part in ['MLB','.cm']for part in path.parts)
   or(path.name.startswith('prog.')and path.name.endswith(('-linux','-win32'))))
 if binary or(compiled and not reviewed):bad.append(name)
 # Verify that the staged bytes also identify the physical retained evidence.
 physical=hashlib.sha256()
 with path.open('rb')as f:
  while True:
   block=f.read(4*1024**2)
   if not block:break
   physical.update(block)
 assert physical.hexdigest()==sha,('physical/index mismatch',name)
 total+=length;ledger.append([name,str(length),sha,index[raw].decode()])
proc.stdin.close();assert proc.wait()==0
if bad:raise SystemExit('REJECTED compiled/binary payloads: '+repr(bad))
with(p/'staged-identities.tsv').open('w')as f:
 w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['path','bytes','sha256','git_blob']);w.writerows(ledger)
record={'exit':0,'files':len(names),'bytes':total,'elapsed_seconds':time.monotonic()-started,
 'policy':'same executable/compiled/NUL and reviewed-14-byte-event-state rules as scan-staged-fast.py; streamed in 4 MiB chunks; every staged blob verified against physical bytes',
 'policy_source_sha256':hashlib.sha256(policy.read_bytes()).hexdigest()}
(p/'staged-payload.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record),flush=True)
