from pathlib import Path
import re,importlib.util
p=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('geometry',p/'generate-geometry.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
s=g.source
names=['tfo_id','wc_tfo','wc_dumas_tfo','helix5XXX_tfo','helix3XXX_tfo','g37_a38_tfo','a38_g37_tfo']
out=''
for name in names:
 block=s[s.index(name+'\n'if name!='tfo_id'else name+' ='):]
 block=block.split('\n\n',1)[0]
 rhs=re.sub(r'--[^\n]*','',block.split('=',1)[1]).strip()
 out+=' val '+name+'=D.delay(fn()=>'+g.render(g.Expr(rhs).parse())+')\n'
(p/'relationships.sml').write_text(out)
out=''
for name in ['anticodon','pseudoknot']:
 start=s.index(name+'_domains\n');body=s[start:s.index('\n    ]',start)+6]
 body=re.sub(r'--[^\n]*','',body)
 body=re.sub(r"\{\-'\-\}",'',body)
 body=re.sub(r'INT_LIT\((\d+)\)',r'\1',body)
 body=body.split('[',1)[1].rsplit(']',1)[0]
 functions=[re.sub(r'\s+',' ',v.strip()).replace("'",'Prime')for v in body.split(',')if v.strip()]
 value='F.empty()'
 for f in reversed(functions):value='F.cons(D.delay(fn()=>'+f+'),'+value+')'
 out+=' val '+name+'_domains='+value+'\n'
 initial='F.defer(fn()=>if input="nope"then raise Fail"This will never be the result of getArgs"else F.empty())'if name=='pseudoknot'else'F.empty()'
 out+=' fun '+name+' input=search('+initial+') '+name+'_domains '+name+'_constraint\n'
(p/'domains.sml').write_text(out)
print('seven relationships and two complete source domain lists generated')
