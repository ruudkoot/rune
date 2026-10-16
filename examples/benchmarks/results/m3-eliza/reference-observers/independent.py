from pathlib import Path
import json
r=Path(__file__).resolve().parent;data=json.loads((r/'data.json').read_text());lines=(r/'eliza.stdin').read_text().splitlines();punct=' .!?, '
responses=[(key.split(),messages)for key,messages in data['responses']];conjugates=dict(data['conjugates'])
def trim(text):return text.strip(' .!?,')
def conjugate(default,tail):
 words=tail if tail else default;words=[conjugates.get(word.upper(),word)for word in words]
 if words and words[-1]=='I':words[-1]='me'
 return' '.join(words)
def session(prefix):
 positions=[0]*len(responses);repeat=0;previous=[];output=[]
 for text in lines[:prefix]:
  words=trim(text).split()
  if not words:continue
  if words==previous:message=data['repeated'][repeat%len(data['repeated'])];repeat+=1
  else:
   for i,(key,messages)in enumerate(responses):
    suffix=None
    for at in range(len(words)):
     tail=words[at:]
     if [word.upper()for word in tail[:len(key)]]==key:suffix=tail[len(key):];break
    if suffix is None:continue
    template=messages[positions[i]%len(messages)];positions[i]+=1
    if template.startswith('?'):message=template[1:]+' '+conjugate(words,suffix)+'?'
    elif template.startswith('.'):message=template[1:]+' '+conjugate(words,suffix)+'.'
    else:message=template
    break
   else:raise AssertionError('no fallback')
  output.append(message+'\n\n');previous=words
 return''.join(output)
lengths=[]
for prefix in range(20):
 expected=session(prefix).encode();assert expected==(r/(str(prefix)+'.session')).read_bytes(),prefix;lengths.append(len(expected))
for name,n in [('smoke',20),('fast',1300),('normal',13000),('large',65000)]:
 expected=''.join(str(lengths[i%20])+'\n'for i in range(1,n+1));assert expected.encode()==(r/(name+'.lengths')).read_bytes()
(r/'lengths.json').write_text(json.dumps(lengths)+'\n');print('PASS all20completeprefixes and every original length through65000iterations')
