from pathlib import Path
import struct,math,json
p=Path(__file__).resolve().parent
def single(text):return struct.unpack('>f',int(text,16).to_bytes(4,'big'))[0]
def solve(a,b):
 a=[row[:]+[rhs]for row,rhs in zip(a,b,strict=True)];n=len(b)
 for k in range(n):
  pivot=max(range(k,n),key=lambda i:abs(a[i][k]));a[k],a[pivot]=a[pivot],a[k]
  assert a[k][k]!=0
  for i in range(k+1,n):
   ratio=a[i][k]/a[k][k]
   for j in range(k+1,n+1):a[i][j]-=ratio*a[k][j]
   a[i][k]=0.0
 result=[0.0]*n
 for i in range(n-1,-1,-1):result[i]=(a[i][n]-sum(a[i][j]*result[j]for j in range(i+1,n)))/a[i][i]
 return result
records=[]
for file in ['data.0','data.1','data.2','fem.stdin']:
 rows={line.split()[0]:line.split()[1:]for line in(p/(file+'.observations')).read_text().splitlines()}
 ints=list(map(int,rows['idatabase']));reals=list(map(single,rows['rdatabase']))
 nn,ne,nm,np=ints[:4]
 nodes=[reals[2*i:2*i+2]for i in range(nn)]
 bc=ints[4:4+nn];dofs=[];count=0
 for flags in bc:
  row=[]
  for divisor in [100,10,1]:
   if(flags//divisor)%10==1:count+=1;row.append(count)
   else:row.append(0)
  dofs.append(row)
 assert [x for row in dofs for x in row]==list(map(int,rows['degrees']))
 assert count==int(rows['degree-count'][0])
 elements=[ints[4+nn+3*i:4+nn+3*i+3]for i in range(ne)]
 materials=[reals[2*nn+2*i:2*nn+2*i+2]for i in range(nm)]
 matrix=[[0.0]*count for _ in range(count)];load=[0.0]*count;bandwidth=[0]*count;geometry=[]
 for nl,nr,material in elements:
  a,b=nodes[nl-1],nodes[nr-1];dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy)
  assert length>0
  c,s=dx/length,dy/length;ea=materials[material-1][0]
  local=[-c,-s,0.0,c,s,0.0];indices=dofs[nl-1]+dofs[nr-1]
  active=[i for i in indices if i]
  for i in active:bandwidth[i-1]=max(bandwidth[i-1],i-min(active)+1)
  for i,gi in enumerate(indices):
   for j,gj in enumerate(indices):
    if gi and gj:matrix[gi-1][gj-1]+=ea/length*local[i]*local[j]
  geometry.append((nl,nr,ea,length,c,s))
 for i in range(np):
  node=ints[4+nn+3*ne+i]
  px,py,moment=reals[2*nn+2*nm+3*i:2*nn+2*nm+3*i+3]
  for degree,value in zip(dofs[node-1],[px,py,moment],strict=True):
   if degree:load[degree-1]+=value
 diagonal=[];address=0
 for i,width in enumerate(bandwidth):address+=1 if i==0 else width;diagonal.append(address)
 assert diagonal==list(map(int,rows['diagonal']))
 lower=[[0.0]*count for _ in range(count)];actual=[[0.0]*count for _ in range(count)]
 av=iter(map(single,rows['stiffness']));lv=iter(map(single,rows['decomposition']))
 for i in range(count):
  first=0 if i==0 else i-(diagonal[i]-diagonal[i-1])+1
  for j in range(first,i+1):
   value=next(av);actual[i][j]=actual[j][i]=value;lower[i][j]=next(lv)
 assert next(av,None)is None and next(lv,None)is None
 assert load==list(map(single,rows['load']))
 mnorm=max(sum(abs(x)for x in row)for row in matrix)
 assembly=max(abs(actual[i][j]-matrix[i][j])for i in range(count)for j in range(count))/mnorm
 assert assembly<=2e-6,(file,'assembly',assembly)
 decomposition=max(abs(actual[i][j]-sum(lower[i][k]*lower[j][k]for k in range(min(i,j)+1)))for i in range(count)for j in range(count))/mnorm
 assert decomposition<=1e-5,(file,'decomposition',decomposition)
 reference=solve(matrix,load);observed=list(map(single,rows['solution']))
 unorm=max(map(abs,reference));bnorm=max(map(abs,load))
 difference=max(abs(a-b)for a,b in zip(observed,reference,strict=True))
 assert difference<=1e-12+2e-4*unorm,(file,'solution',difference,unorm)
 residual=max(abs(sum(matrix[i][j]*observed[j]for j in range(count))-load[i])for i in range(count))
 scaledResidual=residual/(mnorm*max(map(abs,observed))+bnorm)
 assert scaledResidual<=1e-5,(file,'equilibrium',scaledResidual)
 full=list(map(single,rows['displacement']))
 expected=[0.0 if degree==0 else observed[degree-1]for row in dofs for degree in row]
 assert full==expected
 forces=[]
 for nl,nr,ea,length,c,s in geometry:
  du=full[(nr-1)*3]-full[(nl-1)*3];dv=full[(nr-1)*3+1]-full[(nl-1)*3+1]
  forces.append(ea/length*(du*c+dv*s))
 seen=list(map(single,rows['forces']));fnorm=max(map(abs,forces))
 forceError=max(abs(a-b)for a,b in zip(seen,forces,strict=True))
 assert forceError<=1e-10+1e-5*fnorm,(file,'force',forceError,fnorm)
 perturbed=observed[:];perturbed[max(range(count),key=lambda i:abs(reference[i]))]+=0.01*unorm
 assert max(abs(a-b)for a,b in zip(perturbed,reference,strict=True))>1e-12+2e-4*unorm
 record=dict(input=file,degrees=count,assembly_relative_norm=assembly,decomposition_relative_norm=decomposition,solution_relative_norm=difference/unorm,equilibrium_scaled_residual=scaledResidual,force_relative_norm=forceError/fnorm,perturbation_rejected=True)
 records.append(record);print(record,flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
