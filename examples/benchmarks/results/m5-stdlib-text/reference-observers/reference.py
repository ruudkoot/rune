from pathlib import Path
import subprocess,json,hashlib,collections
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/stdlib';d=p/'observer-source';d.mkdir(exist_ok=True)
prefix='''module B0=Bytes
module S0=String
module NativeSys=Sys
let hook=ref(fun(_:Obj.t)->())
let copy_hook=ref(fun(_:B0.t)->())
let blit_hook=ref(fun(_:B0.t)->())
let iter_hook=ref(fun(_:int)->())
module Sys=struct include NativeSys
 let opaque_identity value=(!hook)(Obj.repr value);NativeSys.opaque_identity value
end
module Bytes=struct include B0
 let copy value=let result=B0.copy value in (!copy_hook)result;result
 let blit source start dest offset length=B0.blit source start dest offset length;(!blit_hook)dest
 let iter f input=let calls=ref 0 in B0.iter(fun c->incr calls;f c)input;(!iter_hook)!calls
end
module String=struct include S0
 let blit source start dest offset length=S0.blit source start dest offset length;(!blit_hook)dest
 let iter f input=let calls=ref 0 in S0.iter(fun c->incr calls;f c)input;(!iter_hook)!calls
end
'''
for name in ['bytes','string']:
 src=(up/(name+'_bench.ml')).read_text().split('let () =')[0]
 (d/(name+'_observed.ml')).write_text(prefix+src)
byte_names=['bytes_get','bytes_set','bytes_cat','bytes_sub','bytes_blit','bytes_concat','bytes_iter','bytes_map','bytes_trim','bytes_index','bytes_contains','bytes_uppercase_ascii']
string_names=['string_get','string_sub','string_blit','string_concat','string_iter','string_map','string_trim','string_index','string_contains','string_uppercase_ascii','string_split_on_char','string_compare','string_equal']
calls=[(name,n)for name in byte_names+string_names for n in [0,1,5,575]]
body='''module B=Bytes_observed
module S=String_observed
let seed=Int32.of_string"0x811C9DC5"
let mix h v=Int32.mul(Int32.logxor h v)16777619l
let hash_string input=String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))seed input
let hash_bytes input=Bytes.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))seed input
let hash_parts words=List.fold_left(fun h word->
  mix(String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))h word)0l)seed words
let run name n=
 let state=ref seed and observed=ref 0 and copied=ref None in
 let record value=state:=mix !state value;incr observed in
 let consume obj=
  let value=if name="bytes_set"then 0l
    else if name="bytes_get"||name="string_get"then Int32.of_int(Char.code(Obj.obj obj))
    else if name="bytes_index"||name="string_index"||name="string_compare"||name="string_equal"then Int32.of_int(Obj.obj obj)
    else if name="bytes_contains"||name="string_contains"then if Obj.obj obj then 1l else 0l
    else if name="string_split_on_char"then hash_parts(Obj.obj obj)
    else if String.starts_with ~prefix:"bytes_" name then hash_bytes(Obj.obj obj)
    else hash_string(Obj.obj obj)
  in record value in
 B.hook:=consume;S.hook:=consume;
 B.copy_hook:=(fun bytes->copied:=Some bytes);
 B.blit_hook:=(fun bytes->record(hash_bytes bytes));S.blit_hook:=(fun bytes->record(hash_bytes bytes));
 B.iter_hook:=(fun count->record(Int32.of_int count));S.iter_hook:=(fun count->record(Int32.of_int count));
 (match name with
'''
for name in byte_names+string_names:body+=' |"'+name+'"->'+('B'if name.startswith('bytes_')else'S')+'.'+name+' n\n'
body+=''' |_ -> failwith"selector");
 assert(!observed=n);
 if name="bytes_set"then(match !copied with None->failwith"copy not observed"|Some bytes->state:=mix !state(hash_bytes bytes));
 Printf.printf "%s %d:%lX\\n" name n !state
let ()=List.iter(fun(name,n)->run name n)['''+';'.join('("'+name+'",'+str(n)+')'for name,n in calls)+']\n'
(d/'Observer.ml').write_text(body)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','bytes_observed.ml','string_observed.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=180);(p/'results.reference').write_bytes(out)
text=(p/'text.reference').read_bytes();assert len(text)==574
def mix(h,v):return((h^v)*16777619)&0xffffffff
seed=0x811c9dc5
def digest(data,h=seed):
 for c in data:h=mix(h,c)
 return h
def model(name,n):
 h=seed;copy=bytearray(text);key=name.split('_',1)[1]
 equal=sum(v*v for v in collections.Counter(text.split(b' ')).values())
 for i in range(1,n+1):
  if key=='get':value=text[i%len(text)]
  elif key=='set':copy[i%len(text)]=32;value=0
  elif key=='cat':value=digest(b'I AM A FISH'+text)
  elif key=='sub':start=i%(len(text)-2);value=digest(text[start:start+2])
  elif key=='blit':start=i%(len(text)-32);value=digest(text[start:start+32])
  elif key=='concat':value=digest(b'I AM A FISH')
  elif key=='iter':value=len(text)
  elif key=='map':value=digest(b'!'*len(text))
  elif key=='trim':value=digest(b'We need a trim')
  elif key=='index':value=text.index(b'r')
  elif key=='contains':value=int(b'r'in text)
  elif key=='uppercase_ascii':value=digest(text.upper())
  elif key=='split_on_char':
   value=seed
   for word in text.split(b' '):value=mix(digest(word,value),0)
  elif key=='compare':value=0
  elif key=='equal':value=equal
  else:raise AssertionError(name)
  h=mix(h,value)
 if key=='set':h=mix(h,digest(copy))
 return str(n)+':'+format(h,'X')
lines=out.decode().splitlines();assert len(lines)==len(calls)
for (name,n),line in zip(calls,lines):
 actual_name,result=line.split();assert actual_name==name and result==model(name,n),(line,model(name,n))
print('PASS',len(calls),'original operation/edge-count results and independent byte/word models')
(p/'reference-metadata.json').write_text(json.dumps(dict(
 ocaml=subprocess.check_output(['ocamlopt','-version']).decode().strip(),
 source_sha256={name:hashlib.sha256((up/(name+'_bench.ml')).read_bytes()).hexdigest()for name in ['bytes','string']},
 cases=len(calls),equal_pairs=sum(v*v for v in collections.Counter(text.split(b' ')).values())),indent=2)+'\n')
