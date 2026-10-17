#
#      Patricia Fasel
#      Los Alamos National Laboratory
#      1990 August
#
# Copyright, 1990, The Regents of the University of California.
# This software was produced under a U.S. Government contract (W-7405-ENG-36)
# by the Los Alamos National Laboratory, which is operated by the University
# of California for the U.S. Department of Energy.  The U.S. Government is
# licensed to use, reproduce, and distribute this software.  Permission is
# granted to the public to copy and use this software without charge, provided
# that this notice and any statement of authorship are reproduced on all
# copies.  Neither the Government nor the University makes any warranty,
# express or implied, or assumes any liability for the use of this software.
#

from pathlib import Path
import math,json
p=Path(__file__).resolve().parent
N=16
def gen(seed):
 x=31453257.0*seed+271829.0
 return (x-float((int(x)//655357)*655357))/655357.0
def initial(count):
 positions=[]
 for i in range(1,count+1):
  x=16.0*gen(float(i)/float(count+1));positions.append((x,16.0*gen(x)))
 return positions,[(0.0,0.0)]*count
def density(positions):
 a=[0.0]*(N*N)
 for x,y in positions:
  i,j=int(x),int(y);ip,jp=(i+1)%N,(j+1)%N;dx=x-float(i);dy=y-float(j)
  for u,v,value in [(i,j,(1.0*(1.0-dx))*(1.0-dy)),(ip,j,(1.0*dx)*(1.0-dy)),(i,jp,(1.0*(1.0-dx))*dy),(ip,jp,(1.0*dx)*dy)]:
   assert 0<=u<N and 0<=v<N;a[u*N+v]+=value
 return a
def relax(mesh,rhs,n):
 result=[]
 for i in range(n):
  for j in range(n):
   lo=(i-1)%n;hi=(i+1)%n
   if i==0 and 0<j<n-1:hi=n-2 # retained source top-edge quirk
   jl,jh=(j-1)%n,(j+1)%n
   neighbors=((mesh[lo*n+j]+mesh[i*n+jl])+mesh[i*n+jh])+mesh[hi*n+j]
   result.append(0.25*rhs[i*n+j]+0.25*neighbors)
 return result
def fine_constants(n):
 return [3.0 if i in(0,n-1)and j in(0,n-1)else 4.0 if i in(0,n-1)else 5.0 if j in(0,n-1)else 6.0 for i in range(n)for j in range(n)]
def potential(phi,rho,depth):
 # The source reverses its vCycle parameters. Its fineMesh ignores the
 # recursive coarse result, so positive-depth values have this closed form.
 first=relax(rho,phi,N)
 return relax(first,phi,N)if depth==0 else[a+b for a,b in zip(first,fine_constants(N))]
def fields(phi):
 return ([phi[((i-1)%N)*N+j]-phi[i*N+j]for i in range(N)for j in range(N)],
         [phi[i*N+(j+1)%N]-phi[i*N+j]for i in range(N)for j in range(N)])
def push(positions,velocities,ef,dt):
 ex,ey=ef;outp=[];outv=[];acc=0.0;vel=0.0
 for(x,y),(vx,vy)in zip(positions,velocities):
  i,j=int(x),int(y);ip,jp=(i+1)%N,(j+1)%N;dx=x-float(i);dy=y-float(j)
  ax=1.0*(ex[i*N+j]*(1.0-dy)+ex[i*N+jp]*dy)
  ay=1.0*(ey[i*N+j]*(1.0-dx)+ey[ip*N+j]*dx)
  tx=ax*dt+vx;ty=ay*dt+vy
  px=tx*dt+x;py=ty*dt+y
  def wrap(x):return x-16.0 if x>=16.0 else x+16.0 if x<0.0 else x
  outp.append((wrap(px),wrap(py)));outv.append((tx,ty))
  acc=max(acc,max(abs(ax),abs(ay)));vel=max(vel,max(abs(tx),abs(ty)))
 # timeStep's swapped maxVel/maxAcc binding is intentionally preserved.
 return outp,outv,(math.sqrt(acc*acc+2.0*vel)-acc)/vel
def original(path):
 text=path.read_text().splitlines();states=[]
 for start in range(2,len(text),5):
  assert text[start].startswith('step ')
  state={}
  for line in text[start+1:start+5]:
   name,*values=line.split();state[name]=list(map(float,values))
  states.append(state)
 assert len(states)==11
 return states
metadata=[]
for count in[1,2,3,18,80,300]:
 expected=original(p/(str(count)+'.trace'));positions,velocities=initial(count)
 phi=potential([0.0]*(N*N),density(positions),3);dt=0.001;depth=0;errors=[];equal=0;numbers=0;minimum_boundary_gap=1.0
 for step in range(11):
  actual=dict(dt=[dt],phi=phi,positions=[x for pair in positions for x in pair],velocities=[x for pair in velocities for x in pair])
  for key,values in actual.items():
   assert len(values)==len(expected[step][key])
   for a,b in zip(values,expected[step][key]):
    assert math.isfinite(a)and math.isfinite(b)
    error=abs(a-b)/(1+abs(b));errors.append(error);equal+=(a==b);numbers+=1
  for pair in positions:
   for x in pair:
    assert 0<=x<16.0
    gap=abs(x-round(x))
    if gap:minimum_boundary_gap=min(minimum_boundary_gap,gap)
  if step<10:
   phi=potential(phi,density(positions),depth)
   positions,velocities,dt=push(positions,velocities,fields(phi),dt);depth=(depth+1)%3
 assert max(errors)<1e-12,(count,max(errors))
 metadata.append(dict(particles=count,numbers=numbers,exact_matches=equal,maximum_scaled_difference=max(errors),minimum_nonzero_cell_boundary_gap=minimum_boundary_gap))
(p/'independent-metadata.json').write_text(json.dumps(dict(scope='Independent binary64 state simulator uses the constant fineMesh closed form instead of the unused multigrid dependency graph; full-state reference observation adds terminal demand',traces=metadata),indent=2)+'\n')
print(json.dumps(metadata,indent=2))
