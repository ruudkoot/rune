from pathlib import Path
import csv,shutil,hashlib
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
names=['comp_lab_zift-lazy','comp_lab_zift-strict','comp_lab_nozift-lazy','comp_lab_nozift-strict']
for part in ['figures','kernel','check']:shutil.copy(p/(part+'.sml'),s/'shared'/('hartel-comp-lab-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
for name in names:
 policy='BenchNeed'if name.endswith('lazy')else'BenchStrict';mode='true'if'_zift-'in name else'false'
 d=s/name;d.mkdir();u=d/'upstream';u.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchCompLabFn('+policy+')\n structure Check=BenchCompLabCheckFn(Kernel)\n val run=Check.run '+mode+'\nend\n')
 for file in ['Main.hs','Makefile','comp_lab_zift.faststdout','comp_lab_zift.stdout','comp_lab_zift.slowstdout']:shutil.copy(p/'source'/file,u/file)
 shutil.copy(p/'Fast2haskell.hs',u/'Fast2haskell.hs')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n*.reference -text -whitespace\n')
 for profile,repetitions,size,threshold,seconds,memory in [('smoke',1,1,0,30,1048576),('normal',100,5,1280,600,4194304),('large',100,9,2304,3600,8388608)]:
  key='3-'+str(size)+'-'+str(threshold)+'-'+('zift'if mode=='true'else'plain')
  data=(p/'cases'/(key+'.reference')).read_bytes()
  code=str(sum(data)+len(data))+'/'+str(len(data))
  (d/(profile+'.reference')).write_bytes(data)
  (d/(profile+'.expected')).write_text(str(repetitions)+':'+str(repetitions*len(data))+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml']+['shared/hartel-comp-lab-'+part+'.sml'for part in ['figures','kernel','check']]+[name+'/benchmark.sml','shared/main.sml']
  args=' '.join(map(str,[repetitions,size,threshold]))+' '+profile+'.reference '+code
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/comp_lab_zift',args,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'graphs,persistent-trees,component-labelling,sharing,allocation-lifetimes,hartel',profile+'.reference','exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/comp-lab-tests.sml')
data=root/'tests/benchmarks/data/comp-lab';shutil.copytree(p/'data',data)
(data/'FILES').write_text((p/'data-list').read_text())
(data/'.gitattributes').write_text('cases/** -text -whitespace\n')
script=(root/'tests/benchmarks/check-cacheprof.sh').read_text()
a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+['examples/benchmarks/shared/hartel-comp-lab-'+part+'.sml'for part in ['figures','kernel','check']]+['tests/benchmarks/comp-lab-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('cacheprof','comp-lab').replace('complete original assembly, opcode, driver and demand controls hold','complete original component states, persistent trees and demand controls hold')
(root/'tests/benchmarks/check-comp-lab.sh').write_text(script)
checker=(p.parent/'hartel-wave4main-originals/check-parallel.py').read_text().replace("{'wave4main-lazy','wave4main-strict'}",repr(set(names))).replace('final-wave4main-parallel.','final-comp-lab-parallel.')
(p/'check-parallel.py').write_text(checker)
# Record the source's inactive non-sifting labelling function explicitly.
f=s/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;variants=list(r)
revision=next(r['revision']for r in csv.DictReader((s/'upstreams.tsv').open(),delimiter='\t')if r['source']=='nofib')
path='spectral/hartel/comp_lab_zift/Main.hs';sha=hashlib.sha256((p/'source/Main.hs').read_bytes()).hexdigest()
variants.append(dict(zip(fields,['nofib',revision,'spectral/hartel/comp_lab_zift',path,'comp_lab_nozift','Haskell','inactive non-sifting label mapping','not stated in source heading',sha,'import','ported as comp_lab_nozift-lazy/strict using the original f_comp_lab_diff-prime with f_no_zift; retain positive tiling and full renderer; no new algorithm replaces source trees; source helper f_main_field-prime also selects this mode with negative size but the benchmark Main itself requires positive tiling','no separate individual program notice stated; retain complete module and Fast2haskell shim'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(variants)
print('Imported four labelling/data policies with complete references')
