from pathlib import Path
import struct,json
p=Path(__file__).resolve().parent
MASK=2**64-1
def hashbytes(data):
 h=0
 for b in data:h=(h*31+b)&MASK
 return h
def parse(data):
 magic,length,objects,w32,w64=struct.unpack('>5I',data[:20]);assert magic==0x8495a6be and len(data)==20+length
 pos=20
 def byte():
  nonlocal pos
  b=data[pos];pos+=1;return b
 def word(n):
  nonlocal pos
  value=int.from_bytes(data[pos:pos+n],'big');pos+=n;return value
 def block():
  c=byte()
  if c>=128:return(c>>4)&7,c&15
  assert c in[8,19];h=word(4 if c==8 else 8);return h>>10,h&255
 def integer():
  c=byte()
  if 64<=c<128:return c-64
  assert c in[0,1,2]
  return word({0:1,1:2,2:4}[c])
 def real():
  nonlocal pos
  c=byte();assert c in[11,12]
  value=struct.unpack(('>'if c==11 else'<')+'d',data[pos:pos+8])[0];pos+=8;return value
 count,tag=block();assert tag==0
 edges=[]
 for i in range(count):
  assert block()==(3,0)
  a=integer();b=integer();w=real();assert a>=0 and b>=0 and 0<=w<1
  edges.append((a,b,w))
 assert pos==len(data)and objects==(2*count+1 if count else 0)
 assert w32==(8*count+1 if count else 0)and w64==(7*count+1 if count else 0)
 return edges
records=[]
for name,scale,ef in [('smoke',6,4),('normal',12,16),('large',14,16)]:
 data=(p/(name+'.marshal')).read_bytes();edges=parse(data);assert len(edges)==ef*(2**scale)
 maximum=max(max(a,b)for a,b,_ in edges)
 graph=[[]for _ in range(maximum+1)];selfloops=0
 for a,b,w in edges:
  if a==b:selfloops+=1;continue
  # Independent append/reverse model of source prepending.
  graph[a].append((b,w));graph[b].append((a,w))
 for row in graph:row.reverse()
 def weighted_hash():
  h=0
  for vertex,row in enumerate(graph):
   h=(h*31+vertex)&MASK;h=(h*31+len(row))&MASK
   for target,weight in row:
    h=(h*31+target)&MASK;h=(h*31+int(weight*100000000))&MASK
  return h
 row=dict(profile=name,scale=scale,edge_factor=ef,edges=len(edges),vertices=len(graph),selfloops=selfloops,
          adjacency_edges=sum(map(len,graph)),marshal_bytes=len(data),marshal_hash=format(hashbytes(data),'X'),
          adjacency_hash=format(weighted_hash(),'X'))
 records.append(row);print(row,flush=True)
 if name=='smoke':
  (p/'smoke.edges').write_text(''.join(f'{a} {b} {w:.17g}\n'for a,b,w in edges))
  (p/'smoke.adjacency').write_text(''.join(str(i)+' '+' '.join(f'{target}:{weight:.17g}'for target,weight in row)+'\n'for i,row in enumerate(graph)))
(p/'independent-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
for name in ['smoke','normal','large']:
 data=(p/(name+'.csv')).read_bytes()
 print('prototype',name,len(data),format(hashbytes(data),'X'),flush=True)
