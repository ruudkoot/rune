from pathlib import Path
import hashlib, itertools, json, resource, subprocess

p=Path(__file__).resolve().parent
letters='THIRYWELVN'
answers=[]
for values in itertools.permutations(range(10)):
    t,h,i,r,y,w,e,l,v,n=values
    thirty=y+t*10+r*100+i*1000+h*10000+t*100000
    twelve=e+v*10+l*100+e*1000+w*10000+t*100000
    ninety=y+t*10+e*100+n*1000+i*10000+n*100000
    if thirty+5*twelve==ninety:answers.append(dict(zip(letters,values)))
assert answers==[dict(zip(letters,[1,9,4,2,5,3,0,7,6,8]))],answers
print('PASS independent exhaustive 10! assignment search: unique solution',flush=True)
mapping=(p/'first.txt').read_bytes()
assert dict((line[0],int(line[-1])) for line in mapping.decode().splitlines())==answers[0]
meta=[]
for profile,count,timeout,memory in [('smoke',1,30,1024**3),('normal',300,600,4*1024**3),('large',1500,3600,8*1024**3),('upstream-fast',30,30,1024**3)]:
    def limits(): resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
    result=subprocess.run([str(p/'original'),str(count)],capture_output=True,check=True,
                          timeout=timeout,preexec_fn=limits)
    assert result.stdout==mapping*count
    if profile!='smoke':
        suffix={'normal':'stdout','large':'slowstdout','upstream-fast':'faststdout'}[profile]
        assert result.stdout==Path('/home/ruud/reference/ghc/nofib/spectral/cryptarithm2/cryptarithm2.'+suffix).read_bytes()
    output=p/(profile+'.output');output.write_bytes(result.stdout)
    meta.append({'profile':profile,'count':count,'timeout':timeout,'memory_bytes':memory,
                 'output_bytes':len(result.stdout),'output_sha256':hashlib.sha256(result.stdout).hexdigest()})
    print('PASS original, independent mapping and available pinned fixture',profile,count,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
