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
import math,re,json
p=Path(__file__).resolve().parent
notice=(p/'source/GamtebMain.hs').read_text().split('module GamtebMain')[0]
# This independent eager work-queue model is derived from the credited program;
# retain its complete authorship and permission notice on the generated model.
source=(p/'source/InitTable.hs').read_text()
def table(label,transform):
 body=re.search(r'\b'+label+r'\s*=\s*\[([^\]]+)\]',source,re.S)[1]
 return[transform(float(x.strip()))for x in body.split(',')]
energies=table('erg',math.log)
cross=[table(label,lambda x:-30.0 if x<1e-7 else math.log(2.2*x))for label in ['xc','xp','xpe']]
audit=dict(transport_events=0,collisions=0,pair_events=0,isos_rejections=0,rotation_rejections=0,max_random_integer=0)
def random(seed):
 def rem(value,modulus):
  integer=math.trunc(value);audit['max_random_integer']=max(audit['max_random_integer'],abs(integer))
  return value-(integer//modulus)*modulus
 return(rem(314557*seed+2711,65599)/65599,rem(2711*seed+314557,71123)/71123)
def probability(e):
 logE=math.log(e);index=1
 while index<35 and logE>energies[index-1]:index+=1
 i=max(index,2);fraction=(logE-energies[i-2])/(energies[i-1]-energies[i-2])
 values=[math.exp(xs[i-2]+fraction*(xs[i-1]-xs[i-2]))for xs in cross]
 return index,(*values,(values[0]+values[1])+values[2])
def distance(position,direction):
 x,y,z=position;u,v,w=direction
 def plane(at):return 100.0 if v==0 or y>=at else(at-y)/v
 def cylinder():
  if u*u+w*w==0:return 100.0
  if u!=0:
   m=w/u;b=z-m*x;s=m*m+1;r=math.sqrt(s-b*b)
   xx=(-m*b+r)/s if u>0 else(-m*b-r)/s
   return(xx-x)/u
  if u==0 and v!=0:
   m=w/v;b=z-m*y;r=math.sqrt(1-x*x)
   yy=(r-b)/m if v>0 else(-r-b)/m
   return(yy-y)/v
  return math.sqrt(1-x*x)-z if w>0 else-math.sqrt(1-x*x)-z
 def smaller(a,b):return a if a[0]<b[0]else b
 d,surface=smaller(smaller((plane(0),1),(cylinder(),2)),smaller((plane(20),3),(plane(30),4)))
 return d+1e-7,surface
def isotropic(seed):
 _,r2=random(seed);r3,r4=random(r2);t1=2*r4-1;t2=2*r3-1;rsq=t1*t1+t2*t2
 if rsq>1:
  audit['isos_rejections']+=1
  raise RuntimeError('source isos rejection demands its self-referential seed')
 u=2*rsq-1;t3=math.sqrt(1-u*u)/rsq
 return(u,t1*t3,t2*t3)
def rotate(direction,a,rn):
 while True:
  r1,r2=random(rn);nextSeed,r3=random(r2);t1=2*r1-1;t2=2*r3-1;radius=t1*t1+t2*t2
  if radius<=1:break
  audit['rotation_rejections']+=1;rn=nextSeed
 rr=math.sqrt((1-a*a)/radius);t1*=rr;t2*=rr;u,v,w=direction;wsq=1-w*w
 if wsq<1e-7:return(t1,t2,w*a)
 s=math.sqrt(wsq)
 return(u*a+(t1*u*w-t2*v)/s,v*a+(t1*v*w-t2*u)/s,w*a-t1*s)
def klein(e,r):
 a=1/e;b=2*e+1;c=1/b;d=math.log(b);f=(2*e*(1+e)*c*c+4*a)+(1-2*a*(1+a))*d
 def fit(x2,x3,x4,x5,x7):
  return 1+x2*(x2*((2*x7+x4)-x3+x2*((x5-x7)-x4))-x7)
 if e>1.16666667:
  aa=1.65898+a*(0.62537*a-1.00796);bb=aa/f
  if r>bb:return(0.3*math.exp(((d-1.20397)/(1-bb))*(bb-r)))*e
  cc=aa/(3.63333+a*(5.44444*a-4.66667))
  return fit(r/bb,2.1,cc,1.4,0.5*aa)*e
 aa=f/(b+c);bb=0.5*f;cc=1-c
 return fit(r,3*cc,aa,2*cc,bb)*e
def emit_sources(seed,n):
 if n<=1:
  index,prob=probability(6);nextSeed,_=random(seed)
  return[(((0.,0.,0.),(0.,1.,0.),1.,6.,index,1,nextSeed),prob)]
 r1,r2=random(seed);left=n//2
 return emit_sources(r1,left)+emit_sources(r2,n-left)
def run(n):
 results=[];stats=[];queue=[('particle',pair)for pair in reversed(emit_sources(.5,n))]
 while queue:
  action,payload=queue.pop()
  if action=='stats':stats.extend(payload);continue
  audit['transport_events']+=1
  particle,prob=payload;pos,direction,weight,energy,index,cell,seed=particle
  r,r1=random(seed);dSurf,surface=distance(pos,direction);pComp,pPair,pPhot,pTot=prob
  dColl=-(math.log(r)/pTot)
  dist=min(dColl,dSurf);pos=tuple(x+v*dist for x,v in zip(pos,direction))
  if dColl<dSurf:
   stats.append((8,1.));audit['collisions']+=1
   nextSeed,r2=random(seed);roulette,_=random(r2)
   newWeight=weight*(1-pPhot/pTot)
   if not(newWeight>.25):
    if newWeight*cell<roulette*.5:
     stats.append((5,1.));continue
    newWeight=.5/cell
   weight=newWeight;seed=nextSeed
   nextSeed,r2=random(seed);r3,r4=random(r2)
   if r1<pComp/(pTot-pPhot):
    inputEnergy=1.956917*energy;outputEnergy=klein(inputEnergy,r3)
    angle=(1+1/inputEnergy)-1/outputEnergy;energy=.511008*outputEnergy
    newIndex,newProb=probability(energy)
    if energy<=.001:stats.append((4,1.));continue
    direction=rotate(direction,angle,r4)
   else:
    audit['pair_events']+=1;energy=.511008;weight=2*weight
    newIndex,newProb=probability(energy)
    if energy<=.001:stats.append((4,1.));continue
    direction=isotropic(r3)
   queue.append(('particle',((pos,direction,weight,energy,newIndex,cell,nextSeed),newProb)))
  else:
   stats.append((9,1.))
   if surface in[1,2,4]:
    kind={1:1,2:2,4:3}[surface];stat={1:3,2:1,4:2}[surface]
    results.append((kind,index,weight));stats.append((stat,1.));continue
   if cell==1:
    stats.append((7,1.));s1,s2=random(seed)
    a=(pos,direction,.5*weight,energy,index,2,s1)
    b=(pos,direction,.5*weight,energy,index,2,s2)
    queue.extend([('particle',(b,prob)),('particle',(a,prob))]);continue
   roulette,r2=random(seed);nextSeed,_=random(r2)
   if roulette<.5:
    post=[(6,1.),(12,weight)]
    queue.extend([('stats',post),('particle',((pos,direction,2*weight,energy,index,1,nextSeed),prob))])
   else:stats.extend([(6,1.),(10,1.),(11,weight)])
 return results,stats
records=[]
for n in[1,2,3,10,100,1000,5000]:
 actualR,actualS=run(n)
 expectedR=[tuple([int(a),int(b),float(c)])for a,b,c in map(str.split,(p/(str(n)+'.results')).read_text().splitlines())]
 expectedS=[(int(a),float(b))for a,b in map(str.split,(p/(str(n)+'.stats')).read_text().splitlines())]
 assert len(actualR)==len(expectedR)and len(actualS)==len(expectedS),(n,len(actualR),len(expectedR),len(actualS),len(expectedS))
 sameR=all(a==b for a,b in zip(actualR,expectedR));sameS=all(a==b for a,b in zip(actualS,expectedS))
 maximum=max([abs(a[2]-b[2])for a,b in zip(actualR,expectedR)]+[abs(a[1]-b[1])for a,b in zip(actualS,expectedS)])
 assert all(a[:2]==b[:2]for a,b in zip(actualR,expectedR))and all(a[0]==b[0]for a,b in zip(actualS,expectedS))
 assert maximum<1e-12,(n,maximum)
 record=dict(particles=n,results=len(actualR),stats=len(actualS),exact_results=sameR,exact_stats=sameS,maximum_error=maximum)
 records.append(record);print(record,flush=True)
(p/'independent-metadata.json').write_text(json.dumps(dict(profiles=records,audit=audit,scope='Independent eager LIFO event queue and separate result/stat logs; source self-referential rejection arm raises explicitly if demanded'),indent=2)+'\n')
