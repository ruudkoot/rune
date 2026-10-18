from pathlib import Path
import subprocess,json,struct,math
p=Path(__file__).resolve().parent;d=p/'hash-source';d.mkdir(exist_ok=True)
values=[0.0,-0.0,0.1,0.5,1.0,12.34,128.0,255.0,math.sqrt(2)]
def ocaml(x):
 text=format(x,'.17g')
 return text if'.'in text or'e'in text.lower()else text+'.'
pairs=[(a,b)for a in values for b in values]
source='let cases=['+';'.join('('+ocaml(a)+','+ocaml(b)+')'for a,b in pairs)+']\nlet ()=List.iter(fun p->Printf.printf "%d\\n"(Hashtbl.hash p))cases\n'
source+='''let memo f=
 let table=Hashtbl.create 1000 in fun key->
 try Hashtbl.find table key with Not_found->
 if Hashtbl.length table>1000 then Hashtbl.clear table;
 let value=f key in Hashtbl.add table key value;value
let ()=let calls=ref 0 in let f=memo(fun key->incr calls;key+1)in
 for i=0 to 1000 do assert(f i=i+1)done;
 List.iter(fun i->ignore(f i);Printf.eprintf "%d\\n"!calls)[0;1001;0;1001]
'''
(d/'Reference.ml').write_text(source)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','hash-observer','Reference.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(d/'hash-observer')],cwd=d,capture_output=True,check=True,timeout=60)
(p/'float-hashes.reference').write_bytes(r.stdout);(p/'memo-counts.reference').write_bytes(r.stderr)
def rotate(x,n):return((x<<n)|(x>>(32-n)))&0xffffffff
def mix(h,d):
 d=(d*0xcc9e2d51)&0xffffffff;d=rotate(d,15);d=(d*0x1b873593)&0xffffffff
 return(rotate(h^d,13)*5+0xe6546b64)&0xffffffff
def finish(h):
 h^=h>>16;h=(h*0x85ebca6b)&0xffffffff;h^=h>>13;h=(h*0xc2b2ae35)&0xffffffff;h^=h>>16
 return h&0x3fffffff
def mixed_real(h,x):
 hi,lo=struct.unpack('>II',struct.pack('>d',x))
 if x==0:hi=lo=0
 return mix(mix(h,lo),hi)
rows=[]
for pair,line in zip(pairs,r.stdout.decode().splitlines()):
 actual=int(line);expected=finish(mixed_real(mixed_real(mix(0,2048),pair[0]),pair[1]))
 assert actual==expected,(pair,actual,expected);rows.append(dict(key=pair,hash=actual))
assert len(rows)==81
assert r.stderr.decode().splitlines()==['1001','1002','1003','1003']
(p/'float-hashes.json').write_text(json.dumps(rows,indent=2)+'\n')
print('PASS 81 original float-pair hashes vs independent bit/Murmur model; memo hit/clear sequence [1001,1002,1003,1003]')
