from pathlib import Path
import re,json
p=Path(__file__).resolve().parent;t=(p/'source/Main.hs').read_text()
ctors=json.loads((p/'ast-constructors.json').read_text())
builders=[]
for name,args,ctor,body in re.findall(r'^\s+(f_m_\w+|c_m_\w+)\s*([^=;]*?)=\s*(F_P\w+|C_P\w+)([^;]*);',t,re.M):
 if ctor not in ctors:raise ValueError(ctor)
 fields=body.split();assert len(fields)==len(ctors[ctor]),name
 builders.append(('fun '+name+' '+args.strip()if args.strip()else'val '+name)+'=D.delay(fn()=>'+ctor+('('+','.join(fields)+')'if fields else'')+')')
# Only literal numeric token constants; no guessed tag mapping.
for name,value in re.findall(r'^\s+(c_tok_\w+)=\((\d+) :: Int\);',t,re.M):builders.append('val '+name+'='+value)
# Error literals are observed from the unmodified module separately.
errors=json.loads((p/'errors.json').read_text())
for name,text in errors.items():builders.append('val '+name+'='+json.dumps(text))
block=t[t.index('    c_par_tparname='):t.index('    f_tokenize a_theprog=')]
definitions=re.findall(r'^\s+(c_par_\w+)=(.*?);',block,re.M|re.S)
grammar=[];caches=[]
cache_types=json.loads((p/'grammar-types-sml.json').read_text())
for name,body in definitions:
 body=re.sub(r'--[^\n]*','',body)
 body=body.replace('(:)','cons')
 # Semantic list joins carry memoized attributes. Grammar choice lists remain ordinary setup lists.
 body=body.replace('f_parrep_right cons []','f_parrep_right cellCons (cellNil())')
 body=body.replace('f_parrepplus_right cons []','f_parrepplus_right cellCons (cellNil())')
 body=body.replace('f_parseq cons ','f_parseq cellCons ')
 body=re.sub(r'\s+',' ',body).strip()
 caches.append('val cache_'+name+':(X.tokens L.delay -> '+cache_types[name]+' parsed)option ref=ref NONE')
 grammar.append(('fun 'if not grammar else'and ')+name+' tokens=\n (case !cache_'+name+' of SOME parser=>parser |NONE=>\n let val parser=('+body+') in cache_'+name+':=SOME parser;parser end) tokens')
# Nonterminals use these two source operator constant parsers.
helpers='''fun c_par_op_placeholder()=()\n'''
# c_par_unop/op0.. etc already included in definitions; c_tok_unnametable isn't a grammar definition.
output=(p/'parser-prefix.sml').read_text()+'\n'+'\n'.join(builders)+'\n'+(p/'builders-extra.sml').read_text()+'\n'+'\n'.join(caches)+'\n'+'\n'.join(grammar)+'\n type input=X.input\n val input=X.chars\n'+(p/'benchmark-body.sml').read_text()+'\nend\n'
(p/'kernel.sml').write_text(output)
print('constructor adapters',len(builders),'grammar nonterminals',len(grammar))
