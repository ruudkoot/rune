from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent;d=p/'observer-source'
source='''module H=Reference
let show action=
 let table=H.create ~random:false 1 in for i=0 to 31 do H.add table i i done;
 let first=ref true and visits=ref [] in
 let callback key value=
  visits:=(key,value):: !visits;
  if !first then(begin first:=false;for i=32 to 95 do H.add table i i done end)in
 (if action="iter"then H.iter callback table
  else ignore(H.fold(fun key value n->callback key value;n+1)table 0));
 Printf.printf "%s %d %d %s\\n"action(H.length table)(Array.length table.H.data)
 (String.concat ","(List.map(fun(k,v)->string_of_int k^":"^string_of_int v)(List.rev !visits)))
let ()=show "iter";show "fold"
'''
(d/'Traversal.ml').write_text(source)
with(d/'traversal-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','traversal-observer','Reference.ml','Traversal.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'traversal-observer')],cwd=d,timeout=60);(p/'traversal.reference').write_bytes(out)
lines=['structure StdlibHashtblTraversalTests=struct',' structure H=BenchStdlibHashtbl']
for line in out.decode().splitlines():
 action,size,buckets,visits=line.split();pairs=[tuple(map(int,x.split(':')))for x in visits.split(',')]
 literal='['+','.join('('+str(a)+','+str(b)+')'for a,b in pairs)+']'
 lines.append(''' val _=T.check("stdlib-hashtbl/source-resize-during-'''+action+'''",fn()=>
 let val table=H.create H.Generic 1
     fun loop i last f=if i>last then()else(f i;loop(i+1)last f)
     val _=loop 0 31(fn i=>H.add table i i)
     val first=ref true val visits=ref[]
     fun callback key value=(visits:=(key,value):: !visits;
       if !first then(first:=false;loop 32 95(fn i=>H.add table i i))else())
     val _='''+('H.iter callback table'if action=='iter'else'(H.fold(fn k=>fn v=>fn n=>(callback k v;n+1))table 0;())')+'''
 in H.length table='''+size+''' andalso H.bucketCount table='''+buckets+''' andalso rev(!visits)='''+literal+'''end)''')
lines.append('end');(p/'traversal-tests.sml').write_text('\n'.join(lines)+'\n')
print('PASS original iter/fold resize observers; preserved exact visit order and final table sizes')
