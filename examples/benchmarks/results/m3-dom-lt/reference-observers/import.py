from pathlib import Path
import csv,shutil,json,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/dom-lt-originals';up=root/'tests/out/benchmarks/pinned/nofib/spectral/dom-lt'
parts=['word','intmap','intset','graph','kernel','reader','driver']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('nofib-dom-lt-'+part+'.sml'))
name='dom-lt';dest=suite/name;dest.mkdir();shutil.copytree(up,dest/'upstream')
dependency=p/'dependencies/containers-0.6.7'
for path in ['LICENSE','containers.cabal','src/Data/IntMap/Internal.hs','src/Data/IntMap/Strict/Internal.hs','src/Data/IntSet/Internal.hs','src/Utils/Containers/Internal/BitUtil.hs','include/containers.h']:
 source=dependency/path
 if source.exists():
  target=dest/'upstream-containers-0.6.7'/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy(source,target)
shutil.copy(p/'dependency-identities.json',dest/'DEPENDENCIES.json')
shutil.copy(p/'semidominator-minimum.patch',dest/'semidominator-minimum.patch')
shutil.copy(up/'ghc-examples.in',dest/'ghc-examples.in');shutil.copy(p/'corpus.parents',dest/'expected-parents.txt')
(dest/'.gitattributes').write_text('upstream/** -text -whitespace\nupstream-containers-0.6.7/** -text -whitespace\nghc-examples.in -text -whitespace\n')
(dest/'benchmark.sml').write_text('''structure Benchmark =
struct
  val name = "dom-lt"
  structure Program = BenchDomFn (struct val checkInitialized = false end)
  structure Driver = BenchDomDriverFn (Program)
  val run = Driver.run
end
''')
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']==name for r in rows)
for profile,n in [('smoke',0),('normal',400),('large',2000)]:
 shutil.copy(p/(profile+'.stdout'),dest/(profile+'.expected'))
 sources=['shared/input.sml']+['shared/nofib-dom-lt-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
 rows.append(dict(zip(fields,[name,profile,'nofib','spectral/dom-lt','ghc-examples.in '+str(n)+' expected-parents.txt',name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'graphs,mutable-arrays,higher-order,word64','ghc-examples.in,expected-parents.txt','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
records=[]
for file in ['ghc-examples.in','expected-parents.txt']:
 data=(dest/file).read_bytes();records.append(dict(path=file,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
(dest/'DATA-IDENTITIES.json').write_text(json.dumps(records,indent=2)+'\n')
data=root/'tests/benchmarks/data/dom-lt';data.mkdir();shutil.copytree(p/'cases',data/'cases')
for file in ['repair-threshold.parents','containers.reference','corpus.parents']:shutil.copy(p/file,data/file)
shutil.copy(up/'ghc-examples.in',data/'ghc-examples.in');(data/'.gitattributes').write_text('ghc-examples.in -text -whitespace\n')
s=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""').replace('source/ghc-examples.in','ghc-examples.in').replace('dom-lt/zero-fill-normal-allocator-is-separate','dom-lt/semantic-target-enables-initialization-checks')
(root/'tests/benchmarks/dom-lt-tests.sml').write_text(s)
script=(root/'tests/benchmarks/check-bspt.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml']+['examples/benchmarks/shared/nofib-dom-lt-'+part+'.sml'for part in parts]+['tests/benchmarks/dom-lt-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('bspt','dom-lt').replace('original geometric commands, signed rational arithmetic, tree demand and batch sharing hold','corrected original/model dominators, containers behavior, initialized reads and bad-parent rejection hold');(root/'tests/benchmarks/check-dom-lt.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-dom-lt-parallel.'").replace("{'atom-lazy','atom-strict'}","{'dom-lt'}");(p/'check-parallel.py').write_text(s)
