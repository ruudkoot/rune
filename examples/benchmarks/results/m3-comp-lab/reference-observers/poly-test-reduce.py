from pathlib import Path
import subprocess,re,json,resource
p=Path(__file__).resolve().parent;root=Path.cwd()
text=(p/'tests.sml').read_text();starts=[m.start()for m in re.finditer(r'(?m)^ val _=check',text)];assert len(starts)==113
base=[root/'tests/basis/harness.sml',root/'examples/benchmarks/shared/input.sml',root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'figures.sml',p/'kernel.sml',p/'check.sml']
def cap():resource.setrlimit(resource.RLIMIT_DATA,(1024**3,1024**3))
records=[]
def test(count):
 prefix=text if count==113 else text[:starts[count]]+'\nend\n'
 file=p/('poly-prefix-'+str(count)+'.sml');file.write_text(prefix)
 driver=p/('poly-prefix-'+str(count)+'-driver.sml')
 driver.write_text(''.join('use '+json.dumps(str(x))+';\n'for x in base+[file]))
 with(p/('poly-prefix-'+str(count)+'.log')).open('w')as log:r=subprocess.run(['/home/ruud/.local/rune-hosts/polyml/bin/poly','-H','16','--maxheap','512','--stackspace','64','-q','--error-exit','--use',str(driver)],cwd=p/'data',stdout=log,stderr=subprocess.STDOUT,timeout=120,preexec_fn=cap)
 log=(p/('poly-prefix-'+str(count)+'.log')).read_text()
 record=dict(checks=count,exit=r.returncode,internal_error='entryNumber - not a record'in log);records.append(record);print(record,flush=True)
 return record['internal_error']
if test(0):
 last='failure before first assertion'
else:
 low,high=0,113
 assert test(high)
 while high-low>1:
  middle=(low+high)//2
  if test(middle):high=middle
  else:low=middle
 last=dict(last_good=low,first_bad=high,assertion=text[starts[high-1]:starts[high]if high<113 else len(text)])
print(last,flush=True)
(p/'poly-reduction-results.json').write_text(json.dumps(dict(runs=records,reduction=last),indent=2)+'\n')
