from pathlib import Path
import subprocess,resource,hashlib,json,shutil
ref=Path(__file__).resolve().parent
for name in ['fasta3','revcomp2']:
 with(ref/(name+'-build.log')).open('w')as log:subprocess.run(['ocamlopt','-O2','-o',name,name+'.ml'],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(120,120))
table=bytes.maketrans(b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',b'TVGHEFCDIJMLKNOPQYSAABWXRZ'*2)
def independent(data):
 records=[];header=None;sequence=[]
 for line in data.splitlines():
  if line.startswith(b'>'):
   if header is not None:records.append((header,b''.join(sequence)));sequence=[]
   header=line
  else:sequence.append(line)
 if header is not None:records.append((header,b''.join(sequence)))
 output=[]
 for header,seq in records:
  reverse=seq[::-1].translate(table)
  output.append(header+b'\n'+b''.join(reverse[i:i+60]+b'\n'for i in range(0,len(reverse),60)))
 return b''.join(output)
metadata=[]
for profile,size in [('smoke',1000),('normal',50000),('large',500000)]:
 data=subprocess.check_output([str(ref/'fasta3'),str(size)],timeout=135,preexec_fn=bounded);(ref/(profile+'.fasta')).write_bytes(data)
 work=ref/('work-'+profile);work.mkdir(exist_ok=True);(work/'input25000000.txt').write_bytes(data)
 output=subprocess.check_output([str(ref/'revcomp2')],cwd=work,timeout=135,preexec_fn=bounded);assert output==independent(data)
 (ref/(profile+'.output')).write_bytes(output);metadata.append({'profile':profile,'generator':'pinnedSandmarkfasta3','parameter':size,'input_bytes':len(data),'output_bytes':len(output),'input_sha256':hashlib.sha256(data).hexdigest(),'output_sha256':hashlib.sha256(output).hexdigest(),'comparison':'complete independent record reversal/complement/wrap60'})
 print('PASS original and independent complete reverse complement',profile,flush=True)
(ref/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
