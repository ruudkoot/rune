from pathlib import Path
from decimal import Decimal,localcontext
import json,math
ref=Path(__file__).resolve().parent
zero=(Decimal(0),Decimal(0));one=(Decimal(1),Decimal(0))
def add(a,b):return a[0]+b[0],a[1]+b[1]
def sub(a,b):return a[0]-b[0],a[1]-b[1]
def mul(a,b):return a[0]*b[0]-a[1]*b[1],a[0]*b[1]+a[1]*b[0]
def div(a,b):
    denominator=b[0]*b[0]+b[1]*b[1]
    return (a[0]*b[0]+a[1]*b[1])/denominator,(a[1]*b[0]-a[0]*b[1])/denominator
def norm2(a):return a[0]*a[0]+a[1]*a[1]
def evaluate(cs,z):
    p=cs[0];derivative=zero
    for c in cs[1:]:derivative=add(mul(derivative,z),p);p=add(mul(p,z),c)
    return p,derivative
records=[]
with localcontext()as ctx:
    ctx.prec=80
    for percent in [10,50,100]:
        lines=(ref/f'dka-{percent}.output').read_text().splitlines();tag,size=lines[0].split();size=int(size);assert tag=='coefficients'
        cs=[tuple(map(Decimal,line.split()))for line in lines[1:size+1]]
        tag,degree=lines[size+1].split();degree=int(degree);assert tag=='roots'and degree==size-1
        original=[tuple(map(Decimal,line.split()))for line in lines[size+2:]];assert len(original)==degree
        refined=[];maximum=0.0
        for start in original:
            z=start
            for iteration in range(60):
                p,d=evaluate(cs,z);step=div(p,d);z=sub(z,step)
                if norm2(step)<Decimal('1e-130'):break
            else:raise AssertionError(('Newton refinement limit',percent,start))
            refined.append(z);maximum=max(maximum,math.sqrt(float(norm2(sub(z,start)))))
        separation=min(math.sqrt(float(norm2(sub(a,b))))for i,a in enumerate(refined)for b in refined[i+1:])
        assert separation>1e-10
        # Reconstruct every monic coefficient, detecting duplicate/missing roots.
        product=[one]
        for z in refined:
            new=[zero]*(len(product)+1)
            for i,c in enumerate(product):new[i]=add(new[i],c);new[i+1]=sub(new[i+1],mul(c,z))
            product=new
        error=max(norm2(sub(a,div(c,cs[0]))).sqrt()for a,c in zip(product,cs))
        assert error<Decimal('1e-40'),(percent,error)
        (ref/f'dka-{percent}.refined').write_text(str(degree)+'\n'+''.join(str(a)+' '+str(b)+'\n'for a,b in refined))
        records.append({'percent':percent,'coefficients':size,'degree':degree,'precision':80,'original_max_root_error':maximum,'minimum_root_separation':separation,'reconstruction_max_error':str(error)})
        print('PASS refined roots and complete coefficient reconstruction',percent,records[-1],flush=True)
(ref/'root-refinement.json').write_text(json.dumps(records,indent=2)+'\n')
