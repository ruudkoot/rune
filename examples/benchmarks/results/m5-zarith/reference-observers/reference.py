from pathlib import Path
import decimal, functools, hashlib, json, math, os, resource, shutil, subprocess

p = Path(__file__).resolve().parent
root = Path.cwd()
up = root / 'tests/out/benchmarks/upstreams/sandmark'
find = Path.home() / '.opam/default/bin/ocamlfind'
metadata = {'compiler': subprocess.check_output([str(find),'ocamlopt','-version'],text=True).strip(),
            'libraries': {}, 'cases': []}
for library in ['zarith','num']:
    metadata['libraries'][library] = subprocess.check_output([str(find),'query','-format','%v',library],text=True).strip()
for name in ['zarith_fact','zarith_fib','zarith_tak','zarith_pi']:
    source = up / 'benchmarks/zarith' / (name+'.ml')
    shutil.copy(source,p/source.name)
    with (p/('build-'+name+'.log')).open('w') as log:
        subprocess.run([str(find),'ocamlopt','-O2','-package','zarith,num','-linkpkg','-o',name,source.name],
                       cwd=p,check=True,stdout=log,stderr=subprocess.STDOUT)

def original(name,args,expected,label,profile='smoke'):
    timeout,memory = {'smoke':(30,1024**3),'normal':(600,4*1024**3),'large':(3600,8*1024**3)}[profile]
    def limits(): resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
    result = subprocess.run([str(p/name),*map(str,args)],check=True,capture_output=True,
                            timeout=timeout,preexec_fn=limits)
    assert result.stdout.decode()==expected,(name,args,result.stdout[:80],expected[:80])
    output = p/(label+'.expected'); output.write_bytes(result.stdout)
    metadata['cases'].append({'program':name,'arguments':args,'profile':profile,'timeout':timeout,
                             'memory_bytes':memory,'output':output.name,
                             'sha256':hashlib.sha256(result.stdout).hexdigest()})
    print('PASS original and independent reference',name,args,label,flush=True)

for profile,n,count in [('smoke',10,0),('normal',40,10000),('large',40,1000000)]:
    original('zarith_fact',[n,count],str(math.factorial(n))+'\n','fact-'+profile,profile)

@functools.cache
def tak(x,y,z):
    return tak(tak(x-1,y,z),tak(y-1,z,x),tak(z-1,x,y)) if x>y else z

for mode in ['int','natint','Z','num']:
    for profile,n,count in [('smoke',10,0),('normal',30,100),('large',40,2500)]:
        a,b=1,1
        for _ in range(n): a,b=b,a+b
        original('zarith_fib',[mode,n],str(a)+'\n','fib-'+mode+'-'+profile,profile)
        original('zarith_tak',[mode,count],str(tak(18,12,6))+'\n','tak-'+mode+'-'+profile,profile)

# Independent Gauss-Legendre quadratic iteration using Decimal, not an LFT.
with decimal.localcontext() as context:
    context.prec = 10060
    D=decimal.Decimal
    a=D(1);b=1/D(2).sqrt();t=D(1)/4;power=D(1)
    for _ in range(15):
        next_a=(a+b)/2
        b=(a*b).sqrt();t-=power*(a-next_a)**2;a=next_a;power*=2
    text=str((a+b)**2/(4*t)).replace('.','')

def layout(n):
    digits=text[:n]
    if n==0:return ' '*10+'\t:0\n'
    return ''.join(digits[i:i+10].ljust(10)+'\t:'+str(min(i+10,n))+'\n' for i in range(0,n,10))

for n in [0,1,9,10,11,27,128,256,1000,10000]:
    profile='large' if n==10000 else 'normal' if n in [128,256,1000] else 'smoke'
    original('zarith_pi',[n],layout(n),'pi-'+str(n),profile)
(p/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert not subprocess.check_output(['git','-C',str(up),'status','--porcelain']), 'pinned checkout was modified'
