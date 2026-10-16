from pathlib import Path
import hashlib,itertools,json,resource,subprocess
p=Path(__file__).resolve().parent
up=Path('/home/ruud/reference/ghc/nofib/spectral/cryptarithm1')
assert(p/'Main.hs').read_bytes()==(up/'Main.hs').read_bytes()
meta={'compiler':subprocess.check_output(['/usr/bin/ghc','--version'],text=True).strip(),
      'source_sha256':hashlib.sha256((p/'Main.hs').read_bytes()).hexdigest(),'profiles':[]}
answers=[]
for t,h,i,r,y,w,e,l,v,n in itertools.permutations(range(10)):
    if y+t*10+r*100+i*1000+h*10000+t*100000+5*(e+v*10+l*100+e*1000+w*10000+t*100000)==y+t*10+e*100+n*1000+i*10000+n*100000:
        answers.append([t,h,i,r,y,w,e,l,v,n])
assert answers==[[1,9,4,2,5,3,0,7,6,8]]
line=(json.dumps(answers,separators=(',',':'))+'\n').encode()
print('PASS independent full 10! cryptarithm assignment search',flush=True)
for profile,count,suffix,timeout,memory in [('smoke',1,'faststdout',30,1024**3),('normal',3,'stdout',600,4*1024**3),('large',15,'slowstdout',3600,8*1024**3)]:
    def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
    result=subprocess.run([str(p/'original'),str(count)],capture_output=True,check=True,timeout=timeout,preexec_fn=limits)
    assert result.stdout==line*count==(up/('cryptarithm1.'+suffix)).read_bytes()
    (p/(profile+'.output')).write_bytes(result.stdout)
    meta['profiles'].append({'profile':profile,'count':count,'timeout':timeout,'memory_bytes':memory,'output_bytes':len(result.stdout),'output_sha256':hashlib.sha256(result.stdout).hexdigest()})
    print('PASS original, independent and pinned fixture',profile,count,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
