from pathlib import Path
from fractions import Fraction as F
import json
ref=Path(__file__).resolve().parent
def matrix(path):
    fields=path.read_text().split();m,n=map(int,fields[:2]);values=list(map(F,fields[2:]));assert len(values)==m*n
    return [values[i*n:(i+1)*n] for i in range(m)]
def source_lup(original):
    a=[row[:] for row in original];m=len(a);n=len(a[0]);r=min(m,n)
    p=list(range(m));lu=[[F(0)]*n for _ in range(m)];skipped=[]
    for j in range(r):
        selected=max(range(j,m),key=lambda i:abs(a[i][j]))
        p[j],p[selected]=p[selected],p[j];a[j],a[selected]=a[selected],a[j];lu[j],lu[selected]=lu[selected],lu[j]
        for i in range(j+1):lu[i][j]=a[i][j]-sum(lu[i][k]*lu[k][j] for k in range(i))
        if abs(lu[j][j])>F(1,1000000):
            for i in range(j+1,m):lu[i][j]=(a[i][j]-sum(lu[i][k]*lu[k][j] for k in range(j)))/lu[j][j]
        else:skipped.append(j)
    for j in range(r,n):
        for i in range(r):lu[i][j]=a[i][j]-sum(lu[i][k]*lu[k][j] for k in range(i))
    # Independent sparse permutation application replaces the dense product.
    result=[None]*m
    for i in range(m):
        result[p[i]]=[sum((F(1)if i==k else lu[i][k])*lu[k][j]
                         for k in range(min(i,j,r-1)+1))for j in range(n)]
    return result,skipped
records=[]
for label in ['6','128','full']:
    original=matrix(ref/f'crout-{label}.input');actual=matrix(ref/f'crout-{label}.result')
    expected,skipped=source_lup(original)
    error=max(abs(float(x-y))for a,b in zip(actual,expected)for x,y in zip(a,b))
    reconstruction=max(abs(x-y)for a,b in zip(expected,original)for x,y in zip(a,b))
    assert error<1e-9,(label,error)
    records.append({'profile':label,'rows':len(original),'columns':len(original[0]),'skipped_pivots':skipped,'original_vs_exact_max_error':error,'exact_reconstruction_residual':str(reconstruction),'exact_reconstruction_residual_float':float(reconstruction)})
    print('PASS original agrees with exact source arithmetic',records[-1],flush=True)
counterexample=[[F(x)for x in row]for row in [[2,2,0],[1,1,1],[1,0,1]]]
expected,skipped=source_lup(counterexample)
assert expected==[[F(x)for x in row]for row in [[2,2,0],[1,1,1],[1,1,1]]]and skipped==[1]
(ref/'crout-exact.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS three-by-three raw-pivot counterexample; source behavior is preserved rather than repaired')
