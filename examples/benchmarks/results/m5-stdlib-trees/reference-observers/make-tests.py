from pathlib import Path
import json
p=Path(__file__).resolve().parent
for name in ['map','set']:
 f=p/(name+'.sml');s=f.read_text()
 s=s.replace(' fun shape Empty=',' fun decimal n=if n<0 then "-"^Int.toString(~n)else Int.toString n\n fun shape Empty=').replace('Int.toString k^":"','decimal k^":"')
 f.write_text(s)
seqs=json.loads((p/'sequences.json').read_text());refs=(p/'trees.reference').read_text().splitlines()
head='''structure StdlibTreeTests=struct
 structure M=BenchStdlibIntMap
 structure S=BenchStdlibIntSet
 fun comma []=""|comma[x]=x|comma(x::xs)=x^","^comma xs
 fun decimal n=if n<0 then "-"^Int.toString(~n)else Int.toString n
 fun exercise operations=
  List.foldl(fn((remove,k,v),(m,s))=>if remove then(M.remove k m,S.remove k s)
    else(M.add k v m,S.add k s))(M.Empty,S.Empty)operations
'''
body=''
for i,seq in enumerate(seqs):
 ops='['+','.join('('+str(remove).lower()+','+str(k).replace('-','~')+','+str(v).replace('-','~')+')'for remove,k,v in seq)+']'
 body+=' val(m'+str(i)+',s'+str(i)+')=exercise'+ops+'\n'
 body+=' val _=T.check("stdlib-trees/map-shape/'+str(i)+'",fn()=>M.shape m'+str(i)+'='+json.dumps(refs[i*4])+')\n'
 body+=' val _=T.check("stdlib-trees/map-contents/'+str(i)+'",fn()=>comma(List.map(fn(k,v)=>decimal k^":"^decimal v)(M.bindings m'+str(i)+'))='+json.dumps(refs[i*4+1])+')\n'
 body+=' val _=T.check("stdlib-trees/set-shape-and-contents/'+str(i)+'",fn()=>S.shape s'+str(i)+'='+json.dumps(refs[i*4+2])+' andalso comma(List.map decimal(S.elements s'+str(i)+'))='+json.dumps(refs[i*4+3])+')\n'
 body+=' val _=T.check("stdlib-trees/balance-invariants/'+str(i)+'",fn()=>M.invariant m'+str(i)+' andalso S.invariant s'+str(i)+')\n'
tail=''' val _=T.check("stdlib-trees/duplicate-map-path",fn()=>case M.addChanged 7 7(M.add 7 7 M.Empty)of NONE=>true|_=>false)
 val _=T.check("stdlib-trees/duplicate-set-path",fn()=>case S.addChanged 7(S.add 7 S.Empty)of NONE=>true|_=>false)
 val _=T.check("stdlib-trees/missing-map-path",fn()=>case M.removeChanged 8(M.add 7 7 M.Empty)of NONE=>true|_=>false)
 val _=T.check("stdlib-trees/missing-set-path",fn()=>case S.removeChanged 8(S.add 7 S.Empty)of NONE=>true|_=>false)
 val _=T.check("stdlib-trees/map-fold-inorder",fn()=>M.fold(fn k=>fn _=>fn text=>text^Int.toString k)(M.add 2 2(M.add 3 3(M.add 1 1 M.Empty)))""="123")
 val _=T.check("stdlib-trees/set-fold-inorder",fn()=>S.fold(fn k=>fn text=>text^Int.toString k)(S.add 2(S.add 3(S.add 1 S.Empty)))""="123")
end
'''
(p/'tests.sml').write_text(head+body+tail)
