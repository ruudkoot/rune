from pathlib import Path
import subprocess,json,random
p=Path(__file__).resolve().parent;d=p/'cases';d.mkdir(exist_ok=True)
texts=['','\n',' \n\t\n','one','one\n','one\n\n','one\n\n\n two\n','a '*80,
       'a'*63+' x y z','a'*70,'a'*71,'  spaced\twords  \n\n next \r\nline\n']
rng=random.Random(730126)
for i in range(28):
 words=['x'*rng.randint(1,20)for _ in range(2+i*3)]
 texts.append(' '.join(words)+'\n')
texts.append((p/'anomaly.input').read_text())
records=[]
for i,text in enumerate(texts):
 path=d/(str(i)+'.input');path.write_text(text)
 r=subprocess.run([str(p/'observer-source/observer'),str(path)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
 (d/(str(i)+'.stdout')).write_bytes(r.stdout);(d/(str(i)+'.stderr')).write_bytes(r.stderr)
 records.append(dict(index=i,status='pass'if r.returncode==0 else'error',input_bytes=len(text),output_bytes=len(r.stdout),exit=r.returncode))
 print(records[-1],flush=True)
(p/'case-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
