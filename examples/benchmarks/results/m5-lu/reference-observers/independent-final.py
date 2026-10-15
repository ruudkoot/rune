from pathlib import Path
from decimal import Decimal,localcontext
import math
p=Path(__file__).parent/"acquired"
for profile,n in [('smoke',4),('normal',256)]:
 original=list(map(float,(p/(profile+'.lu.input')).read_text().split()))
 packed=list(map(float,(p/(profile+'.lu')).read_text().split()))
 assert len(original)==len(packed)==n*n and all(map(math.isfinite,packed))
 worst=0.0
 for i in range(n):
  for j in range(n):
   terms=[(packed[i*n+k]if i>k else 1.0 if i==k else 0.0)*(packed[k*n+j]if k<=j else 0.0)for k in range(n)]
   scale=max(1.0,abs(original[i*n+j])+sum(map(abs,terms)))
   worst=max(worst,abs(sum(terms)-original[i*n+j])/scale)
 assert worst<64*n*2**-52,(profile,worst)
 with localcontext()as context:
  context.prec=60
  exact=list(map(Decimal.from_float,original))
  for k in range(n-1):
   for row in range(k+1,n):
    factor=exact[row*n+k]/exact[k*n+k]
    for col in range(k+1,n):exact[row*n+col]-=factor*exact[k*n+col]
    exact[row*n+k]=factor
  forward=max(abs(float(a)-b)/max(1.0,abs(float(a)))for a,b in zip(exact,packed))
 print('PASS LU reconstruction and 60-digit elimination',profile,'scaled residual',worst,'relative packed discrepancy',forward,flush=True)
