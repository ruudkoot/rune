from pathlib import Path
import json
p=Path(__file__).resolve().parent
source=(p/'workload-kernel.sml').read_text()
tokens=[];i=0;comment=0
while i<len(source):
 if source.startswith('(*',i):
  comment=1;i+=2
  while comment:
   if source.startswith('(*',i):comment+=1;i+=2
   elif source.startswith('*)',i):comment-=1;i+=2
   else:i+=1
  continue
 if source[i].isspace():i+=1;continue
 start=i
 if source[i]=='"':
  i+=1
  while i<len(source):
   if source[i]=='\\':i+=2
   elif source[i]=='"':i+=1;break
   else:i+=1
  tokens.append(('string',start,i,source[start:i]));continue
 if source[i].isalpha()or source[i]=='_':
  i+=1
  while i<len(source)and(source[i].isalnum()or source[i]in"_'"):i+=1
  tokens.append(('id',start,i,source[start:i]));continue
 tokens.append(('punct',i,i+1,source[i]));i+=1
literals={};replacements=[]
for first,last in zip(tokens,tokens[1:]):
 if first[0]=='id'and first[3]=='text'and last[0]=='string':
  constant=literals.setdefault(last[3],'literal'+str(len(literals)))
  replacements.append((first[1],last[2],constant))
for start,end,value in reversed(replacements):source=source[:start]+' '+value+' '+source[end:]
needle=' fun text s=F.fromList(String.explode s)\n';assert source.count(needle)==1
constants=''.join(' val '+name+'=text '+literal+'\n'for literal,name in literals.items())
source=source.replace(needle,needle+constants)
(p/'kernel-final.sml').write_text(source)
(p/'literal-sharing.json').write_text(json.dumps(literals,indent=2)+'\n')
print('Preserved',len(literals),'distinct finite character-list literals at functor scope;',len(replacements),'source uses')
