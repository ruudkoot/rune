from pathlib import Path
import math,cmath,json
p=Path(__file__).resolve().parent;meta=[]
for profile,power in [('smoke',1),('normal',3),('large',5)]:
 n=64*2**power;lines=(p/'fft'/(profile+'.values')).read_text().splitlines();groups={};label=None
 for line in lines:
  if line in ['INPUT','IAA','RLL']:label=line;groups[label]=[]
  else:
   a,b=map(float,line.split());groups[label].append(complex(a,b))
 assert set(groups)=={'INPUT','IAA','RLL'}and all(len(xs)==n for xs in groups.values())
 assert groups['INPUT']==[complex(63-(i%64),0)for i in range(n)]
 expected=[];repeat=n//64
 for k in range(n):
  if k%repeat:expected.append(0j)
  else:
   q=k//repeat;expected.append(complex(2016*repeat,0)if q==0 else complex(n/2,(n/2)/math.tan(math.pi*q/64)))
 errors={name:max(abs(v-e)for v,e in zip(groups[name],expected))for name in ['IAA','RLL']}
 assert all(error<1e-7 for error in errors.values()),(profile,errors)
 # A direct O(N^2) definition also verifies orientation and the analytic formula.
 direct=[]
 for k in range(n):
  direct.append(sum(x*cmath.exp(2j*math.pi*k*j/n)for j,x in enumerate(groups['INPUT'])))
 direct_error=max(abs(v-e)for v,e in zip(direct,expected));assert direct_error<1e-6,(profile,direct_error)
 meta.append(dict(profile=profile,n=n,max_original_analytic_error=errors,max_direct_dft_analytic_error=direct_error,fft_bound_absolute=1e-7,fft_bound_relative=1e-12))
(p/'independent-fft-metadata.json').write_text(json.dumps(meta,indent=2)+'\n');print('PASS independent positive-sign direct DFT and analytic repeated-ramp spectrum for all three full original FFT profiles')
