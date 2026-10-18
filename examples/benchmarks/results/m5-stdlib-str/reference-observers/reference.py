from pathlib import Path
import subprocess,json,collections
p=Path(__file__).resolve().parent;t=p.parent/'stdlib-text-originals';up=p.parent/'upstreams/sandmark/benchmarks/stdlib'
d=p/'observer-source';d.mkdir(exist_ok=True)
prefix='''module NativeSys=Sys
module OriginalStr=Str
let hook=ref(fun(_:Obj.t)->())
let compiled=ref 0
module Sys=struct include NativeSys
 let opaque_identity value=(!hook)(Obj.repr value);NativeSys.opaque_identity value
end
module Str=struct include OriginalStr
 let regexp value=incr compiled;OriginalStr.regexp value
end
'''
(d/'Observed.ml').write_text(prefix+(up/'str_bench.ml').read_text().split('let () =')[0])
names=['str_regexp','str_string_match','str_search_forward','str_string_partial_match','str_global_replace','str_split']
normal={'str_regexp':20000,'str_string_match':200000,'str_search_forward':2000,'str_string_partial_match':200000,'str_global_replace':2000,'str_split':2000}
profiles={name:dict(smoke=1,normal=normal[name])for name in names};profiles['str_search_forward']['large']=100000;profiles['str_global_replace']['large']=100000
(p/'profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
calls=[(name,'edge',n)for name in names for n in [0,1,5]]+[(name,profile,n)for name,ps in profiles.items()for profile,n in ps.items()]
source='''module B=Observed
let seed=Int32.of_string"0x811C9DC5"
let mix h v=Int32.mul(Int32.logxor h v)16777619l
let digest text=String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))seed text
let parts words=List.fold_left(fun h text->mix(String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))h text)0l)seed words
let run name n=
 let state=ref seed and seen=ref 0 in
 B.compiled:=0;
 B.hook:=(fun obj->
  let value=match name with
  |"str_regexp"->let re=Obj.obj obj in assert(Str.string_match re B.test_regex 0);assert(not(Str.string_match re "Wrong" 0));digest B.test_regex
  |"str_string_match"|"str_string_partial_match"->if Obj.obj obj then 1l else 0l
  |"str_search_forward"->Int32.of_int(Obj.obj obj)
  |"str_global_replace"->digest(Obj.obj obj)
  |"str_split"->parts(Obj.obj obj)
  |_ ->failwith"selector"in state:=mix !state value;incr seen);
 (match name with
'''+'\n'.join(' |"'+name+'"->B.'+name+' n'for name in names)+'''
 |_ ->failwith"selector");
 assert(!seen=n);assert(!(B.compiled)=(if name="str_regexp"then n else 1));
 Printf.printf "%s %d:%lX\\n" name n !state
let ()=List.iter(fun(name,n)->run name n)['''+';'.join('("'+name+'",'+str(n)+')'for name,_,n in calls)+']\n'
(d/'Observer.ml').write_text(source)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','str.cmxa','Observed.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=600);(p/'results.reference').write_bytes(out)
text=(t/'text.reference').read_bytes();pattern=b'Novum Site';position=text.index(pattern);seed=0x811c9dc5
def mix(h,v):return((h^v)*16777619)&0xffffffff
def digest(text):
 h=seed
 for c in text:h=mix(h,c)
 return h
values={'str_regexp':digest(pattern),'str_string_match':0,'str_string_partial_match':0,'str_search_forward':position,'str_global_replace':digest(text.replace(pattern,b'.')),'str_split':mix(digest(text),0)}
results=[];edges=[]
for(name,profile,n),line in zip(calls,out.decode().splitlines()):
 actual,result=line.split();h=seed
 for _ in range(n):h=mix(h,values[name])
 assert actual==name and result==str(n)+':'+format(h,'X'),line
 row=dict(benchmark=name,profile=profile,iterations=n,expected=result)
 (edges if profile=='edge'else results).append(row)
assert len(out.decode().splitlines())==len(calls)
(p/'profile-results.json').write_text(json.dumps(results,indent=2)+'\n')
(p/'edge-results.json').write_text(json.dumps(edges,indent=2)+'\n')
print('PASS',len(calls),'original Str selector results, source compilation scopes and independent literal models')
