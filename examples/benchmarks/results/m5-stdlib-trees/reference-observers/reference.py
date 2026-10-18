from pathlib import Path
import random,json,subprocess,shutil,hashlib
p=Path(__file__).resolve().parent;r=random.Random(19790601)
sequences=[[(False,k,k)for k in range(n)]for n in [0,1,2,3,4,7,15,31,63,100]]
sequences += [[(False,k,k)for k in reversed(range(n))]for n in [3,7,31,100]]
sequences += [[(bool(r.randrange(3)==0),r.randrange(-12,13),r.randrange(-25,26))for _ in range(40)]for _ in range(64)]
(p/'sequences.json').write_text(json.dumps(sequences,indent=2)+'\n')
d=p/'observer-source';d.mkdir(exist_ok=True)
for name in ['map','set']:shutil.copy(p/'library'/(name+'.ml'),d/(name+'_source.ml'))
def ocaml_bool(x):return 'true'if x else'false'
cases='['+';'.join('['+';'.join('('+ocaml_bool(remove)+','+str(k)+','+str(v)+')'for remove,k,v in seq)+']'for seq in sequences)+']'
s='''module Ord=struct type t=int let compare=compare end
module M=Map_source.Make(Ord)
module S=Set_source.Make(Ord)
let rec map_shape=function M.Empty->"."|M.Node{l;v;r;h}->"("^string_of_int v^":"^string_of_int h^" "^map_shape l^" "^map_shape r^")"
let rec set_shape=function S.Empty->"."|S.Node{l;v;r;h}->"("^string_of_int v^":"^string_of_int h^" "^set_shape l^" "^set_shape r^")"
let show seq=
 let m,s=List.fold_left(fun(m,s)(remove,k,v)->if remove then M.remove k m,S.remove k s else M.add k v m,S.add k s)(M.empty,S.empty)seq in
 print_endline(map_shape m);
 print_endline(String.concat ","(List.map(fun(k,v)->string_of_int k^":"^string_of_int v)(M.bindings m)));
 print_endline(set_shape s);
 print_endline(String.concat ","(List.map string_of_int(S.elements s)))
let ()=List.iter show '''+cases+'\n'
(d/'Observer.ml').write_text(s)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','map_source.ml','set_source.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=30);(p/'trees.reference').write_bytes(out)
lines=out.decode().splitlines();assert len(lines)==4*len(sequences)
for i,seq in enumerate(sequences):
 model={}
 for remove,k,v in seq:
  if remove:model.pop(k,None)
  else:model[k]=v
 assert lines[i*4+1]==','.join(str(k)+':'+str(model[k])for k in sorted(model))
 assert lines[i*4+3]==','.join(map(str,sorted(model)))
print('PASS',len(sequences),'original map/set tree shapes and independent ordered contents')
(p/'dependency-identities.json').write_text(json.dumps(dict(ocaml=subprocess.check_output(['ocamlc','-version']).decode().strip(),files={str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted((p/'library').iterdir())}),indent=2)+'\n')
