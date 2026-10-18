from pathlib import Path
import json
p=Path(__file__).resolve().parent
def smlint(n):return str(n).replace('-','~')
rows=json.loads((p/'table-results.json').read_text());hashes=json.loads((p/'hash-results.json').read_text())
lines=['structure StdlibHashtblTests=struct',' structure H=BenchStdlibHashtbl',' structure Hash=BenchStdlibHash',
''' fun number n=if n<0 then "-"^Int.toString(~n)else Int.toString n
 fun join separator []=""|join separator[x]=x|join separator(x::xs)=x^separator^join separator xs
 fun snapshot(table as H.Table{data,...})=
  let val array= !data
      fun cells H.Empty=[]|cells(H.Cons(k,v,n))=(number k^":"^number(!v))::cells(!n)
      fun loop i xs=if i=Array.length array then rev xs
        else let val items=cells(Array.sub(array,i))
         in loop(i+1)(if null items then xs else(Int.toString i^"="^join "," items)::xs)end
  in Int.toString(H.length table)^"/"^Int.toString(Array.length array)^"|"^join "|"(loop 0[])end
 fun run sequence=
  let val table=H.create H.Generic 1
      val _=List.app(fn(opcode,k,v)=>case opcode of 0=>H.add table k v|1=>H.replace table k v|_=>H.remove table k)sequence
      val before=snapshot table
      val _=H.filterMap(fn k=>fn v=>if k mod 3=0 then NONE else SOME(v+1))table
  in(before,snapshot table)end''']
for i,row in enumerate(rows):
 seq='['+','.join('('+','.join(smlint(x)for x in item)+')'for item in row['sequence'])+']'
 lines.append(' val _=T.check("stdlib-hashtbl/source-buckets/'+str(i)+'",fn()=>run '+seq+'=('+json.dumps(row['before'])+','+json.dumps(row['after'])+'))')
lines.append(' val hashes=['+','.join('('+','.join(smlint(n)for n in row)+')'for row in hashes)+']')
lines.append(' val _=T.check("stdlib-hashtbl/original-1005-integer-hashes",fn()=>List.all(fn(n,h,_)=>Hash.integer n=h)hashes)')
lines.append(' val _=T.check("stdlib-hashtbl/original-1005-tuple-hashes",fn()=>List.all(fn(n,_,h)=>Hash.pair(n,n)=h)hashes)')
lines += [
''' val _=T.check("stdlib-hashtbl/unrolled-find-and-tail",fn()=>let val table=H.create H.Integer 64
 val _=List.app(fn k=>H.add table k(k+1))[0,64,128,192,256,320,384]
 in H.findOpt table 0=SOME 1 andalso H.findOpt table 192=SOME 193 andalso H.findOpt table 384=SOME 385 andalso H.findOpt table 448=NONE end)''',
''' val _=T.check("stdlib-hashtbl/duplicate-remove-reveals-older",fn()=>let val table=H.create H.Integer 1
 val _=H.add table 3 10 val _=H.add table 3 20 val _=H.remove table 3
 in H.length table=1 andalso H.findOpt table 3=SOME 10 end)''',
''' val _=T.check("stdlib-hashtbl/traversal-restored-after-exception",fn()=>let val table as H.Table{initial,...}=H.create H.Integer 1
 val _=H.add table 1 2 val _=(H.iter(fn _=>fn _=>raise Fail"probe")table handle Fail _=>())
 in !initial=16 end)''',
'end']
# "before" is infix in SML, avoid rebinding it.
s='\n'.join(lines)+'\n';s=s.replace('val before=','val initialShape=').replace('in(before,','in(initialShape,')
(p/'tests.sml').write_text(s)
