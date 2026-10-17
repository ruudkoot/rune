from pathlib import Path
import math,json,difflib
p=Path(__file__).resolve().parent
records=[]
for policy in ['Need','Strict']:
 for profile in ['smoke','normal','large']:
  for mode in ['activity','spark','pool','eps','portrait']:
   actual=(p/('actual-'+policy+'-'+mode+'-'+profile+'.ps')).read_text()
   expected=(p/(mode+'-'+profile+'.ps')).read_text()
   a=actual.splitlines();b=expected.splitlines()
   assert len(a)==len(b),(policy,profile,mode,len(a),len(b))
   differences=[];allowed=0
   for i,(x,y)in enumerate(zip(a,b)):
    if x==y:continue
    xt=x.split();yt=y.split()
    if len(xt)==len(yt)==3 and xt[-1]==yt[-1]and xt[-1]in['scale','moveto']:
     numbers=list(zip(map(float,xt[:2]),map(float,yt[:2])))
     if all((math.isnan(v)and math.isnan(w))or(v==w)or(math.isfinite(v)and math.isfinite(w)and abs(v-w)<=1e-12+1e-12*abs(w))for v,w in numbers):
      allowed+=1;continue
    differences.append((i+1,x,y))
   if differences:
    print(policy,profile,mode,'unexpected',len(differences))
    for item in differences[:6]:print(item)
   records.append(dict(policy=policy,profile=profile,mode=mode,exact=actual==expected,numeric_spelling_lines=allowed,unexpected=len(differences)))
(p/'render-comparison.json').write_text(json.dumps(records,indent=2)+'\n')
assert all(row['unexpected']==0 for row in records)
print('All',len(records),'complete PostScript outputs match, allowing only equivalent bare numeric operand spelling')
