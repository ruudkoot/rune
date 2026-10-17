from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;cases={
 'duplicate':'-a Int -a Bool','toggle-duplicate':'-b Bool +b Bool','odd':'-a Int -b',
 'plus-non-bool':'+a Int','short-flag':'- Int','long-flag':'-alpha Int',
 'bad-literate':'-lit -a Int'}
metadata=[]
for name,contents in cases.items():
 file=p/(name+'.input');file.write_text(contents+'\n')
 result=subprocess.run([str(p/'source/original'),'1'],input=file.read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=True)
 assert result.stdout==b'Usage: mkhprog [-l] [-m module_name] [-o file_name] [[-flag type] ...]'and not result.stderr
 (p/(name+'.usage')).write_bytes(result.stdout);metadata.append(dict(name=name,exit=result.returncode,usage_bytes=len(result.stdout)))
(p/'invalid-cases.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(len(metadata),'unmodified invalid-specification cases match the usage message')
