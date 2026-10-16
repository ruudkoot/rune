from pathlib import Path
import json,re
r=Path(__file__).resolve().parent;data=json.loads((r/'term-data.json').read_text())
variables=['A','B','C','D','X','Y','Z','U','W'];functions=[name for name,_ in data['rules']];names=variables+functions;assert len(names)==50 and len(set(names))==50;index={name:i for i,name in enumerate(names)}
def parse(s):
 ts=re.findall(r'\(|\)|[^ ()]+',s);pos=0
 def term():
  nonlocal pos
  token=ts[pos];pos+=1
  if token!='(':assert token.startswith('?');return('v',token[1:])
  name=ts[pos];pos+=1;args=[]
  while ts[pos]!=')':args.append(term())
  pos+=1;return('f',name,args)
 value=term();assert pos==len(ts);return value
def expression(t,placeholder=False):
 if t[0]=='v':return'parameter'if placeholder and t[1]=='A'else'T.variable '+str(index[t[1]])
 return'T.app '+str(index[t[1]])+' (fn () => ['+','.join(expression(a,placeholder)for a in t[2])+'])'
def rules_stream(rules):
 if not rules:return'BenchStream.empty ()'
 first,*rest=rules;pair='('+expression(parse(first[0]))+','+expression(parse(first[1]))+')'
 return'BenchLazy.delay (fn () => BenchStream.Cons (BenchLazy.delay (fn () => '+pair+'),'+rules_stream(rest)+'))'
lines=['(* Exact typed-ID/embedded-rule graph extracted from the pinned Haskell source. *)','structure BenchBoyerIds =','struct','  val names = Vector.fromList ['+','.join('"'+name+'"'for name in names)+']','  val trueId = '+str(index['TRUE']),'  val falseId = '+str(index['FALSE']),'  val ifId = '+str(index['IF']),'  val xId = '+str(index['X']),'end','functor BenchBoyerDataFn (T : sig','  type term','  val variable : int -> term','  val app : int -> (unit -> term list) -> term','end) =','struct','  fun rules id = case id of']
for i,(name,rules)in enumerate(data['rules']):lines.append('    '+(''if i==0 else'| ')+str(index[name])+' => '+rules_stream(rules))
lines+=['    | _ => BenchStream.empty ()','  fun theorem parameter = '+expression(parse(data['template']),True),'  fun bindings () = ['+','.join('('+str(index[name])+','+expression(parse(text))+')'for name,text in data['substitution'])+']','end']
(r/'data.sml').write_text('\n'.join(lines)+'\n');(r/'id-map.json').write_text(json.dumps(index,indent=2)+'\n');print('Generated all50typedIDs/41functionrulegraphs, theorem and5bindings')
