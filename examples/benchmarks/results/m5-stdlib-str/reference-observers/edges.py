from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'observer-source'
cases=[
('match','Novum Site','Novum Site',0),('match','Novum Site','Wrong',0),('match','Novum Site','xNovum Site',1),
('match','Novum Site','Novum',0),('partial','Novum Site','Novum',0),('partial','Novum Site','',0),
('partial','Novum Site','Novum Site',0),('partial','Novum Site','Novem',0),('partial','Novum Site','xNovum',1),
('search','Novum Site','xNovum Site',0),('search','Novum Site','absent',0),
('search','Novum Site','Novum Novum Site',1),('search','Novum Site','Novum Site Novum Site',1),
('replace','Novum Site','Novum Site / Novum Site',0),('replace','Novum Site','absent',0),
('split','@','',0),('split','@','@',0),('split','@','@a',0),('split','@','a@',0),
('split','@','a@@b',0),('split','@','@@a@@',0)]
source='''let edges=['''+';'.join('('+json.dumps(mode)+','+json.dumps(pattern)+','+json.dumps(text)+','+str(start)+')'for mode,pattern,text,start in cases)+''']
let state()=try Printf.sprintf "%d:%d"(Str.match_beginning())(Str.match_end())with Not_found|Invalid_argument _->"none"
let ()=List.iter(fun(mode,pattern,text,start)->
 let regex=Str.regexp pattern in
 let result=match mode with
 |"match"->let value=Str.string_match regex text start in string_of_bool value^":"^state()
 |"partial"->let value=Str.string_partial_match regex text start in string_of_bool value^":"^state()
 |"search"->(try let _=Str.search_forward regex text start in state()with Not_found|Invalid_argument _->"none")
 |"replace"->Str.global_replace regex "." text
 |"split"->String.concat "|"(Str.split regex text)
 |_ ->failwith"mode"in print_endline result)edges
'''
(d/'Edges.ml').write_text(source)
with(d/'edges-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','edges-observer','str.cmxa','Edges.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'edges-observer')],cwd=d,timeout=60);(p/'edges.reference').write_bytes(out)
expected=out.decode().splitlines();assert len(expected)==len(cases)
(p/'edge-cases.json').write_text(json.dumps([dict(mode=a,pattern=b,text=c,start=e,expected=result)for(a,b,c,e),result in zip(cases,expected)],indent=2)+'\n')
lines=['structure StdlibStrTests=struct',' structure B=BenchStdlibStr',' structure R=BenchRegexReduxStr',
' fun state()=if Vector.length(!(B.last))=0 then "none"else Int.toString(Vector.sub(!(B.last),0))^":"^Int.toString(Vector.sub(!(B.last),1))']
for i,((mode,pattern,text,start),result)in enumerate(zip(cases,expected)):
 if mode in ['match','partial']:
  op='B.stringMatch'if mode=='match'else'B.partial'
  expression='let val value='+op+' regex text '+str(start)+' in Bool.toString value^":"^state()end'
 elif mode=='search':expression='(B.search regex text '+str(start)+';state())'
 elif mode=='replace':expression='B.replace regex "." text'
 else:expression='let fun join[]=""|join[x]=x|join(x::xs)=x^"|"^join xs in join(B.split regex text)end'
 lines+=[' val _=T.check("stdlib-Str/original-edge/'+str(i)+'",fn()=>let val regex=R.compile '+json.dumps(pattern)+' val text='+json.dumps(text)+' in '+expression+'='+json.dumps(result)+'end)']
for row in json.loads((p/'edge-results.json').read_text()):
 lines+=[' val _=T.check("stdlib-Str/'+row['benchmark']+'/'+str(row['iterations'])+'",fn()=>B.run '+json.dumps(row['benchmark'])+' '+str(row['iterations'])+'='+json.dumps(row['expected'])+')']
lines+=[' val _=T.check("stdlib-Str/reject-corrupt-position",fn()=>((B.check "str_search_forward"(B.Position 273);false)handle Fail _=>true))',
' val _=T.check("stdlib-Str/partial-reject-negative-index",fn()=>((B.partial(R.compile"Novum Site")"Novum"(~1);false)handle Subscript=>true))',
' val _=T.check("stdlib-Str/source-split-middle-empty",fn()=>B.split(R.compile"@")"a@@b"=["a","","b"])','end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
print('PASS',len(cases),'original Str edge observations; generated',len(cases)+18+3,'semantic assertions')
