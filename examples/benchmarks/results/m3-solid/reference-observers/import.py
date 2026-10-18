from pathlib import Path
import shutil,csv,hashlib,subprocess
root=Path.cwd();suite=root/'examples/benchmarks';p=Path(__file__).resolve().parent
for part in ['kernel','check']:shutil.copy(p/(part+'.sml'),suite/'shared'/('hartel-solid-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['solid-lazy','solid-strict'];assert not any(r['benchmark']in names for r in rows)
for name,policy in zip(names,['BenchNeed','BenchStrict']):
 d=suite/name;d.mkdir();up=d/'upstream';up.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchSolidFn('+policy+')\n structure Check=BenchSolidCheckFn(Kernel)\n val run=Check.run\nend\n')
 for file in ['Main.hs','Makefile','solid.faststdout','solid.stdout','solid.slowstdout']:shutil.copy(p/'source'/file,up/file)
 shutil.copy(p/'Fast2haskell.hs',up/'Fast2haskell.hs')
 original=(p/'source/Main.hs').read_text()
 repaired=original.replace('f_f_std_index a_lst a_n=(!!) a_lst a_n;','f_f_std_index a_lst a_n=(!!) a_lst (a_n-1);')
 tmp=p/'Main-index-corrected.hs';tmp.write_text(repaired)
 result=subprocess.run(['diff','-u',str(p/'source/Main.hs'),str(tmp)],capture_output=True);(up/'index-fix.patch').write_bytes(result.stdout)
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 for profile,repetitions,depth,seconds,memory in [('smoke',1,3,30,1048576),('normal',200,9,600,4194304),('large',200,12,3600,8388608)]:
  shutil.copy(p/'scene.input',d/'scene.input');shutil.copy(p/'areas.reference',d/'areas.reference')
  (d/(profile+'.expected')).write_text(str(repetitions)+':'+str(repetitions*depth)+':'+str(repetitions*depth*27)+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml','shared/hartel-solid-kernel.sml','shared/hartel-solid-check.sml',name+'/benchmark.sml','shared/main.sml']
  args=str(repetitions)+' '+str(depth)+' scene.input areas.reference'
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/solid',args,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'numerical,geometry,csg,adaptive-trees,sharing,allocation-lifetimes,hartel','scene.input,areas.reference','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/solid-tests.sml')
data=root/'tests/benchmarks/data/solid';shutil.copytree(p/'data',data);(data/'FILES').write_text((p/'data-list').read_text())
script=(root/'tests/benchmarks/check-fem.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml','examples/benchmarks/shared/hartel-solid-kernel.sml','examples/benchmarks/shared/hartel-solid-check.sml','tests/benchmarks/solid-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('fem','solid').replace('complete binary32 FEM states, cyclic arrays, reports and result checks hold','corrected CSG tables, complete adaptive trees, geometric areas and demand controls hold')
(root/'tests/benchmarks/check-solid.sh').write_text(script)
checker=(p.parent/'hartel-wave4main-originals/check-parallel.py').read_text().replace("{'wave4main-lazy','wave4main-strict'}",repr(set(names))).replace('final-wave4main-parallel.','final-solid-parallel.')
(p/'check-parallel.py').write_text(checker)
f=suite/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;variants=list(r)
revision=next(r['revision']for r in csv.DictReader((suite/'upstreams.tsv').open(),delimiter='\t')if r['source']=='nofib')
path='spectral/hartel/solid/Main.hs'
variants.append(dict(zip(fields,['nofib',revision,'spectral/hartel/solid',path,'solid-unrepaired','Haskell','unrepaired one-based classification lookup','not stated in scanned source heading',hashlib.sha256((p/'source/Main.hs').read_bytes()).hexdigest(),'defer','raw list indexing uses an extra one-based offset: union(OUT,OUT) gives UNKNOWN and depth-nine fixed-scene output overcounts 65 independently sampled cells; only the reviewed one-line index correction is runnable; reconsider unrepaired baselines after upstream indexing is corrected and independent scene counts pass','no separate individual notice stated; retain complete source, shim and original incorrect fixtures separately from repaired references'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(variants)
print('Imported solid2policies withreviewedone-line classification repair')
