from pathlib import Path
import subprocess,json,hashlib
p=Path(__file__).resolve().parent
root=p/'end-to-end-data';root.mkdir(exist_ok=True)
records=[]
for row in json.loads((p/'codegen-cases.json').read_text()):
 name=row['name'];work=root/name;work.mkdir(exist_ok=True)
 (work/'TestInput.y').write_bytes((p/'grammar-data'/(name+'.input')).read_bytes())
 result=subprocess.run([str(p/'source/original'),'TestInput.y','+RTS','-M1g','-RTS'],cwd=work,capture_output=True,timeout=120)
 (work/'stdout').write_bytes(result.stdout);(work/'stderr').write_bytes(result.stderr)
 target=work/'TestInput.hs'
 assert result.returncode==0 and not result.stdout
 expected=(p/'codegen-data'/(name+'.reference')).read_bytes()
 assert target.read_bytes()==expected
 records.append(dict(name=name,exit=result.returncode,bytes=len(expected),sha256=hashlib.sha256(expected).hexdigest(),stderr_bytes=len(result.stderr)))
 print(records[-1],flush=True)
(p/'end-to-end-cases.json').write_text(json.dumps(records,indent=2)+'\n')
