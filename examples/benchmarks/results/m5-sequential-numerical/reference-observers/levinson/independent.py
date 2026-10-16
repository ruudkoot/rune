from pathlib import Path
from decimal import Decimal,localcontext
import json,math
ref=Path(__file__).resolve().parent
datasets={}
for label in ['a','i','u','e','o']:
    values=list(map(int,(ref/(label+'.pcm')).read_text().replace('~','-').split()))
    assert values[0]==len(values)-1;datasets[label]=values[1:]
def exact_correlations(data,order):
    return [Decimal(sum(data[t]*data[t+lag]for t in range(max(0,len(data)-lag))))/Decimal(2**30)
            for lag in range(order+1)]
def solve(r):
    # Dense Toeplitz Gaussian elimination is independent of Levinson recursion.
    size=len(r)-1
    a=[[r[abs(i-j)] for j in range(size)]+[r[i+1]]for i in range(size)]
    for k in range(size):
        pivot=max(range(k,size),key=lambda i:abs(a[i][k]));a[k],a[pivot]=a[pivot],a[k]
        assert a[k][k]!=0
        for i in range(k+1,size):
            factor=a[i][k]/a[k][k];a[i][k]=Decimal(0)
            for j in range(k+1,size+1):a[i][j]-=factor*a[k][j]
    result=[Decimal(0)]*size
    for i in range(size-1,-1,-1):
        result[i]=(a[i][-1]-sum(a[i][j]*result[j]for j in range(i+1,size)))/a[i][i]
    variance=r[0]-sum(x*ri for x,ri in zip(result,r[1:]))
    return result,variance
records=[]
with localcontext()as ctx:
    ctx.prec=80
    for order in [8,128]:
        lines=(ref/f'order-{order}.output').read_text().splitlines();pos=0
        for label,data in datasets.items():
            lab,size,sigma=lines[pos].split();pos+=1;size=int(size);assert lab==label and size==order+1
            actual=list(map(Decimal,lines[pos:pos+size]));pos+=size
            r=exact_correlations(data,order+1)
            expected,variance=solve(r)
            error=max(abs(a-b)for a,b in zip(actual,expected));variance_error=abs(Decimal(sigma)-variance)
            assert error<Decimal('2e-9')and variance_error<Decimal('2e-10'),(label,order,error,variance_error)
            residual=max(abs(sum(r[abs(i-j)]*actual[j]for j in range(size))-r[i+1])for i in range(size))
            records.append({'label':label,'order':order,'coefficient_max_error':str(error),'variance_error':str(variance_error),'toeplitz_max_residual':str(residual),'precision':80})
            print('PASS independent dense solve',order,label,'coefficient error',error,'variance error',variance_error,flush=True)
        assert pos==len(lines)
(ref/'independent.json').write_text(json.dumps(records,indent=2)+'\n')
