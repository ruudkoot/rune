from pathlib import Path
import subprocess,resource,collections,json,hashlib,shutil
ref=Path(__file__).resolve().parent;up=ref.parent/'upstreams/sandmark/benchmarks/benchmarksgame';data=ref.parent/'revcomp2-originals'
for name in ['knucleotide','knucleotide3']:
 shutil.copy(up/(name+'.ml'),ref/(name+'.ml'))
 with(ref/(name+'-build.log')).open('w')as log:subprocess.run(['ocamlopt','-O2','-o',name,name+'.ml'],cwd=ref,stdout=log,stderr=subprocess.STDOUT,check=True)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(120,120))
queries=[b'GGT',b'GGTA',b'GGTATT',b'GGTATTTTAATT',b'GGTATTTTAATTTATAGT']
def oracle(dna,packed):
 table={};out=[];digits={c:i for i,c in enumerate(b'ATCG')}
 def pack(key):
  value=0
  for byte in key:value=value*4+digits.get(byte,0)
  return value
 def unpack(key,k):
  output=bytearray(k)
  for pos in range(k-1,-1,-1):output[pos]=b'ATCG'[key&3];key>>=2
  return bytes(output)
 for k in [1,2,3,4,6,12,18]:
  if not packed:table={}
  for pos in range(max(0,len(dna)-k+(0 if packed else 1))):
   key=pack(dna[pos:pos+k])if packed else dna[pos:pos+k];table[key]=table.get(key,0)+1
  if k<=2:
   total=sum(table.values());pairs=[(unpack(key,k)if packed else key,value)for key,value in table.items()]
   out.extend(key+b' '+f'{100.0*value/total:.3f}'.encode()+b'\n'for key,value in sorted(pairs,key=lambda pair:(-pair[1],pair[0])));out.append(b'\n')
  else:
   key=queries[[3,4,6,12,18].index(k)];out.append(str(table.get(pack(key)if packed else key,0)).encode()+b'\t'+key+b'\n')
 return b''.join(out)
metadata=[]
for profile in ['smoke','normal','large']:
 raw=(data/(profile+'.fasta')).read_bytes();dna=raw.split(b'>THREE',1)[1].split(b'\n',1)[1].replace(b'\n',b'').upper()
 work=ref/('work-'+profile);work.mkdir(exist_ok=True);(work/'input25000000.txt').write_bytes(raw)
 for name in ['knucleotide','knucleotide3']:
  output=subprocess.check_output([str(ref/name)],cwd=work,timeout=135,preexec_fn=bounded);expected=oracle(dna,name=='knucleotide3');assert output==expected,(name,profile,output,expected)
  (ref/(name+'-'+profile+'.output')).write_bytes(output);print('PASS full original/independent',name,profile,len(dna),'bases',flush=True)
  metadata.append(dict(name=name,profile=profile,input_sha256=hashlib.sha256(raw).hexdigest(),dna_bytes=len(dna),output_sha256=hashlib.sha256(output).hexdigest()))
(ref/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
