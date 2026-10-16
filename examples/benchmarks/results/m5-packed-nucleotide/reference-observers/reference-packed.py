from pathlib import Path
import subprocess,resource,json,difflib
p=Path(__file__).resolve().parent;data=p.parent/'revcomp2-originals';source=(p/'knucleotide3.ml').read_text()
a=source.index('let threshold15 =');b=source.index('let threshold16',a)
adapted=source[:a]+'let threshold15 = 15\n'+source[b:]
(p/'knucleotide3_32.ml').write_text(adapted)
(p/'threshold-adapter.patch').write_text(''.join(difflib.unified_diff(source.splitlines(True),adapted.splitlines(True),fromfile='knucleotide3.ml',tofile='knucleotide3_32.ml')))
for name in ['knucleotide3','knucleotide3_32']:
 with(p/(name+'-reference-build.log')).open('w')as log:subprocess.run(['ocamlopt','-O2','-o',name,name+'.ml'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
queries=[b'GGT',b'GGTA',b'GGTATT',b'GGTATTTTAATT',b'GGTATTTTAATTTATAGT']
def oracle(dna,threshold):
 small={};large={};digits={c:i for i,c in enumerate(b'ATCG')};digits.update({c+32:i for i,c in enumerate(b'ATCG')})
 def number(text):
  value=0
  for c in text:value=4*value+digits.get(c,0)
  return value
 def pack(text):return number(text)if len(text)<=threshold else(number(text[:threshold]),number(text[threshold:]))
 def unpack(key,k):
  value=key if isinstance(key,int)else(key[0]<<(2*(k-threshold)))|key[1];out=bytearray(k)
  for pos in range(k-1,-1,-1):out[pos]=b'ATCG'[value&3];value>>=2
  return bytes(out)
 output=[];stats=[]
 for k in [1,2,3,4,6,12,18]:
  table=small if k<=threshold else large
  for pos in range(max(0,len(dna)-k)):
   key=pack(dna[pos:pos+k]);table[key]=table.get(key,0)+1
  stats.append(dict(k=k,small_entries=len(small),large_entries=len(large),small_total=sum(small.values()),large_total=sum(large.values())))
  if k<=2:
   total=sum(table.values());pairs=[(unpack(key,k),n)for key,n in table.items()]
   output.extend(key+b' '+f'{100.0*n/total:.3f}'.encode()+b'\n'for key,n in sorted(pairs,key=lambda pair:(-pair[1],pair[0])));output.append(b'\n')
  else:
   query=queries[[3,4,6,12,18].index(k)];output.append(str(table.get(pack(query),0)).encode()+b'\t'+query+b'\n')
 return b''.join(output),stats
metadata=[]
for profile in ['smoke','normal','large']:
 raw=(data/(profile+'.fasta')).read_bytes();dna=raw.split(b'>THREE',1)[1].split(b'\n',1)[1].replace(b'\n',b'')
 work=p/('reference-'+profile);work.mkdir(exist_ok=True);(work/'input25000000.txt').write_bytes(raw)
 for width,threshold,exe in [(64,31,'knucleotide3'),(32,15,'knucleotide3_32')]:
  output=subprocess.check_output([str(p/exe)],cwd=work,timeout=180,preexec_fn=cap);expected,stats=oracle(dna,threshold)
  assert output==expected,(profile,width)
  assert output==(p/(profile+'.output')).read_bytes()
  (p/(profile+'-'+str(width)+'.output')).write_bytes(output);metadata.append(dict(profile=profile,width=width,threshold=threshold,scope='unmodified64 original'if width==64 else'explicit threshold observer on64-bit OCaml; not an actual32-bit compiler run',statistics=stats))
  print('PASS complete packed reference/model',profile,width,len(dna),flush=True)
(p/'packed-reference-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
