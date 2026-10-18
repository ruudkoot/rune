from pathlib import Path
import json,struct
p=Path(__file__).resolve().parent
spheres=[(-0.5,-1.0,1.0,0.8),(0.5,-1.0,0.0,0.6),(-0.2,0.5,-0.8,1.2)]
def zsegments(depth,a=-2.0,b=2.0):
 if depth==0:return[(a,b)]
 mid=(a+b)/2
 return zsegments(depth-1,mid-0.001,b)+zsegments(depth-1,a,mid)
def decoded(data):
 assert len(data)%2==0
 words=struct.unpack('>'+str(len(data)//2)+'H',data)
 assert words[0]==3;size=words[1];assert(len(words)-2)%6==0
 pixels=[False]*(size*size);tiles=0
 for i in range(2,len(words),6):
  x,y,width,r,g,b=words[i:i+6]
  assert width>0 and x+width<=size and y+width<=size and all(0<=c<=256 for c in[r,g,b])
  for j in range(y,y+width):
   for k in range(x,x+width):
    assert not pixels[j*size+k],(x,y,width)
    pixels[j*size+k]=True
  tiles+=1
 return size,pixels,tiles
def model(depth):
 size=1<<depth;z=zsegments(depth);pixels=[]
 for y in range(size):
  ya=-2+4*y/size;yb=-2+4*(y+1)/size
  for x in range(size):
   xa=-2+4*x/size;xb=-2+4*(x+1)/size
   hit=False
   for za,zb in z:
    for a,b,c,r in spheres:
     dx=max(xa-a,0.0,a-xb);dy=max(ya-b,0.0,b-yb);dz=max(za-c,0.0,c-zb)
     if dx*dx+dy*dy+dz*dz-r*r<=0:hit=True;break
    if hit:break
   pixels.append(hit)
 return pixels
records=[]
for depth in range(6):
 size,mask,tiles=decoded((p/('source-depth-'+str(depth)+'.raster')).read_bytes())
 expected=model(depth);assert mask==expected,(depth,sum(mask),sum(expected))
 records.append(dict(depth=depth,dimension=size,foreground=sum(mask),tiles=tiles))
 print('PASS',depth,size*size,'pixels independent sphere-box projection mask;',tiles,'nonoverlapping source tiles',flush=True)
(p/'independent-mask-results.json').write_text(json.dumps(records,indent=2)+'\n')
