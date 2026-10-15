from pathlib import Path
p=Path(__file__).parent
escape=b'\x1b'
def goto(x,y):return escape+b'['+str(y).encode()+b';'+str(x).encode()+b'H'
def at(x,y,text):return goto(x,y)+text
opening=b'\x0c'+at(17,5,escape+b'[7mDemonstration program'+escape+b'[0m')+at(48,5,b'Version 1.0')+at(17,7,b'This program illustrates a simple approach')+at(17,8,b'to screen-based interactive programs using')+at(17,9,b'the Hugs functional programming system.')+at(17,11,b'Please press any key to continue ...')
def program(data):
 data=data[1:];name=[];editing=bytearray()
 for c in data:
  if c in [8,127]:
   if name:name.pop();editing.extend(b'\x08_\x08')
   else:editing.append(7)
  elif c==10:break
  elif len(name)<18:name.append(c);editing.append(c)
  else:editing.append(7)
 reply=b'Hello '+bytes(name)+b'!'
 return opening+at(17,15,b'Please enter your name: ')+at(41,15,b'_'*18)+goto(41,15)+editing+at(40-len(reply)//2,18,reply)+goto(1,23)+b"I'm waiting...\n"
result=b''
for n in range(901):
 if n in [0,1,2,3,150,400,900]:
  actual=(p/(str(n)+'.stdout')).read_bytes();
  if actual!=result:
   index=next(i for i,(a,b) in enumerate(zip(actual,result))if a!=b)
   print(index,repr(actual[max(0,index-15):index+40]),repr(result[max(0,index-15):index+40]),flush=True)
   raise AssertionError(n)
  print('PASS exact independent transducer',n,len(result),flush=True)
 result=program(result)
