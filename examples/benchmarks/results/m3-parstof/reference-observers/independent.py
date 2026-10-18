from pathlib import Path
import json,re,sys,collections
sys.setrecursionlimit(100000)
p=Path(__file__).resolve().parent
keywords=[('TYPE',15),('FTYPE',16),('LET',17),('IN',18),('IF',19),('THEN',20),('ELIF',21),('ELSE',22),('FI',23),('CASE',24)]
punct=[('->',26),('++',31),(':',32),('&',33),('|',34),('<=',35),('~=',37),('==',36),('>=',38),('<',39),('>',40),('=',30),('+',41),('-',42),('*',43),('/',44),('%',45),('~',46),('[',47),(']',50),('{',51),('}',52),('(',53),(')',54),(';',55),(',',56),('#',57)]
def unroll(tree):
 out=[]
 while tree[0]=='(:)':out.append(tree[1]);tree=tree[2]
 assert tree==['[]']
 return out
def escaped(text,at):
 if text[at]!='\\':return text[at],at+1
 c=text[at+1:at+2]
 if c in {'n','t','f','\\',"'",'"'}:return {'n':'\n','t':'\t','f':'\f'}.get(c,c),at+2
 digits=text[at+1:at+3]
 if len(digits)==2 and all(x in '0123456789ABCDEF'for x in digits):
  # Deliberately preserve the observed source subtraction, not standard hex.
  return chr(16*(ord(digits[0])-48)+ord(digits[1])-48),at+3
 raise ValueError('invalid escape')
def lex(text):
 at=0;line=1;out=[]
 while True:
  originalAt=at;originalLine=line
  while at<len(text):
   if text[at]in' \t\f\n':
    line+=text[at]=='\n';at+=1
   elif text.startswith('/*',at):
    end=text.find('*/',at+2)
    if end<0:
     out.append(['(,,)',60,['F_Tokv_err',ord(text[originalAt]),'Illegal comment'],originalLine])
     return out
    line+=text[at:end+2].count('\n');at=end+2
   else:break
  if at==len(text):out.append(['(,,)',61,['C_Tokv_E'],line]);return out
  start=at;c=text[at];token=None
  if c=="'":
   try:
    value,end=escaped(text,at+1)
    if end<len(text)and text[end]=="'":token=(11,['F_Tokv_ch',ord(value)]);at=end+1
   except ValueError:pass
  if token is None and c.isascii()and c.isdigit():
   m=re.match('[0-9]+',text[at:]);at+=len(m[0]);token=(12,['F_Tokv_i',int(m[0])])
  if token is None:
   for word,tag in keywords:
    if text.startswith(word,at):token=(tag,['C_Tokv_E']);at+=len(word);break
  if token is None and c.isascii()and c.isupper():
   word=re.match('[A-Z][A-Za-z0-9]*',text[at:])[0];at+=len(word);token=(25,['F_Tokv_str',word])
  if token is None and c=='"':
   chars=[];index=at+1
   try:
    while index<len(text)and text[index]!='"':
     if text[index]in'\n\r':raise ValueError('line in source string')
     value,index=escaped(text,index);chars.append(value)
    if index<len(text):token=(13,['F_Tokv_str',''.join(chars)]);at=index+1
   except ValueError:pass
  if token is None and c.isascii()and c.islower():
   word=re.match('[a-z][A-Za-z0-9]*',text[at:])[0];at+=len(word);token=(14,['F_Tokv_str',word])
  if token is None:
   for word,tag in punct:
    if text.startswith(word,at):token=(tag,['C_Tokv_E']);at+=len(word);break
  if token is None:token=(60,['F_Tokv_err',ord(c),'Lexical error']);at=start+1
  out.append(['(,,)',token[0],token[1],line])
constructors=json.loads((p/'ast-constructors.json').read_text())
owners={}
for typename,body in re.findall(r'data\n\s+(T_pt\w+)=([^;]+);',(p/'source/Main.hs').read_text()):
 for part in body.split('|'):owners[part.split()[0]]=typename
def checkAst(tree,typ,counts):
 assert tree[0]in constructors and owners[tree[0]]==typ,(typ,tree[:1])
 fields=constructors[tree[0]];assert len(fields)==len(tree)-1
 assert tree[0].startswith(('F_P','C_P'))
 counts[tree[0]]+=1
 for value,field in zip(tree[1:],fields):
  if field=='T_string':assert isinstance(value,str)
  elif field in {'Int','Char'}:assert isinstance(value,int)and -(2**30)<=value<2**30
  else:checkAst(value,field,counts)
results=[]
for name in ['default','identity','application','types','conditional','let-case','lexemes','bad','empty','unterminated-comment']:
 expected=unroll(json.loads((p/(name+'-tokens.reference')).read_text()))
 actual=lex((p/(name+'.input')).read_text())
 assert actual==expected,name
 parsed=json.loads((p/(name+'-parse.reference')).read_text());counts=collections.Counter()
 if parsed[0]=='F_Par_succ':
  checkAst(parsed[1],'T_ptproglist',counts);assert parsed[2]==['[]']
 else:assert parsed[0]=='F_Par_fail'and parsed[1][0]in{'F_Emess_known','C_Emess_uk'}
 results.append(dict(name=name,tokens=len(actual),parse=parsed[0],ast_nodes=sum(counts.values()),constructors=dict(sorted(counts.items()))))
(p/'independent-results.json').write_text(json.dumps(results,indent=2)+'\n')
print('Independent ordered regular-expression lexer agrees for',sum(r['tokens']for r in results),'tokens; complete parsed ASTs satisfy constructor arities and selected 31-bit bounds')
