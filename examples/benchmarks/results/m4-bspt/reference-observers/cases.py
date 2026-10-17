from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'cases';d.mkdir(exist_ok=True)
def point(x,y):return f'{x+5} {y+4}\n'
def command(depth):return point(5,depth+10)
def operand(points):return''.join(point(x,y)for x,y in points)+'         \n'
a=[(200,100),(400,100),(400,300),(200,300)]
b=[(300,100),(500,100),(500,300),(300,300)]
quit=command(460)
cases={
 'quit':quit,
 'polygon':command(10)+operand(a)+quit,
 'area':command(10)+operand(a)+command(410)+quit,
 'classify':command(10)+operand(a)+command(360)+operand([(300,200),(150,200),(200,100)])+quit,
 'partition':command(10)+operand(a)+command(260)+quit,
 'render':command(10)+operand(a)+command(310)+quit,
 'complement':command(10)+operand(a)+command(210)+quit,
 'union':command(10)+operand(a)+command(60)+operand(b)+command(410)+quit,
 'intersection':command(10)+operand(a)+command(110)+operand(b)+command(410)+quit,
 'subtract':command(10)+operand(a)+command(160)+operand(b)+command(410)+quit,
 'null-before-quit':point(0,0)+quit}
records=[]
for name,text in cases.items():
 (d/(name+'.input')).write_text(text)
 r=subprocess.run([str(p/'observer-source/observer')],cwd=p/'observer-source',input=text.encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
 (d/(name+'.output')).write_bytes(r.stdout);(d/(name+'.stderr')).write_bytes(r.stderr)
 record=dict(name=name,exit=r.returncode,input_bytes=len(text),output_bytes=len(r.stdout));records.append(record);print(record,flush=True)
(p/'case-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
