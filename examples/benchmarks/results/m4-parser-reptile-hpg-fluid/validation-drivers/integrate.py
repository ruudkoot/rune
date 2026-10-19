from pathlib import Path
import csv,hashlib,json,shutil,subprocess
root=Path.cwd();suite=root/'examples/benchmarks';private=root/'tests/out/benchmarks'
pin=private/'pinned/nofib';revision='b7391df4540ac8b11b35e1b2e2c15819b5171798'
assert subprocess.check_output(['git','-C',str(pin),'rev-parse','HEAD'],text=True).strip()==revision
def copy(src,dest):
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
def table(path,header,rows):
 with path.open('w',newline='')as f:
  w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(header);w.writerows(rows)
def digest(data):
 word=0
 for c in data:word=(word*31+c)%2**64
 return format(word,'X')
sources={
 'parser':['input.sml','lazy.sml','suspend.sml','hartel-ida-finite.sml','nofib-parser-literals.sml','nofib-parser-lexer.sml','nofib-parser-kernel.sml','nofib-parser-check.sml'],
 'reptile':['input.sml','lazy.sml','suspend.sml','hartel-ida-finite.sml','signed64.sml','nofib-reptile-kernel.sml','nofib-reptile-check.sml'],
 'hpg':['input.sml','lazy.sml','suspend.sml','hartel-ida-finite.sml','finite-binary32.sml','nofib-hpg-random.sml','nofib-hpg-kernel.sml','nofib-hpg-check.sml'],
 'fluid':['input.sml','lazy.sml','suspend.sml','hartel-ida-finite.sml','nofib-linear-float.sml','nofib-fluid-sparse.sml','nofib-fluid-float-show.sml','nofib-fluid-kernel.sml','nofib-fluid-check.sml']}
files={
 'parser':[('literals.sml','literals'),('lexer-kernel.sml','lexer'),('parser-kernel.sml','kernel'),('check.sml','check')],
 'reptile':[('kernel-check.sml','kernel'),('check.sml','check')],
 'hpg':[('rng.sml','random'),('kernel.sml','kernel'),('check.sml','check')],
 'fluid':[('sparse.sml','sparse'),('float-show.sml','float-show'),('kernel.sml','kernel'),('check.sml','check')]}
for family,entries in files.items():
 p=private/('nofib-'+family+'-originals')
 for source,suffix in entries:
  copy(p/source,suite/'shared'/('nofib-'+family+'-'+suffix+'.sml'))
manifest=list(csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t'));header=list(manifest[0])
new=[]
for family in ['parser','reptile','hpg','fluid']:
 p=private/('nofib-'+family+'-originals')
 for policy,delay in [('lazy','BenchNeed'),('strict','BenchStrict')]:
  name=family+'-'+policy
  assert not any(r['benchmark']==name for r in manifest)
  d=suite/name;d.mkdir()
  structure={'parser':'BenchNofibParserFn','reptile':'BenchReptileFn','hpg':'BenchHpgFn','fluid':'BenchFluidFn'}[family]
  checker={'parser':'BenchNofibParserCheckFn','reptile':'BenchReptileCheckFn','hpg':'BenchHpgCheckFn','fluid':'BenchFluidCheckFn'}[family]
  (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel='+structure+'('+delay+')\n structure Check='+checker+'(Kernel)\n val run=Check.run\nend\n')
  identities=[]
  tracked=subprocess.check_output(['git','-C',str(pin),'ls-files','-z','--','real/'+family]).split(b'\0')
  for raw in tracked:
   if not raw:continue
   path=raw.decode();src=pin/path;relative=Path(path).relative_to('real/'+family)
   if src.is_symlink():
    data=src.readlink().as_posix().encode()
    target=d/'upstream'/(relative.as_posix()+'.link');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    identities.append([path,'upstream/'+relative.as_posix()+'.link','symlink-target',len(data),hashlib.sha256(data).hexdigest()])
   else:
    data=src.read_bytes();copy(src,d/'upstream'/relative)
    identities.append([path,'upstream/'+relative.as_posix(),'upstream-file',len(data),hashlib.sha256(data).hexdigest()])
  common=pin/'common/NofibUtils.hs';data=common.read_bytes();copy(common,d/'upstream/common/NofibUtils.hs')
  identities.append(['common/NofibUtils.hs','upstream/common/NofibUtils.hs','canonical-shared-utility',len(data),hashlib.sha256(data).hexdigest()])
  table(d/'UPSTREAM-IDENTITIES.tsv',['source_path','archived_path','kind','bytes','sha256'],identities)
  (d/'NOTICE').write_text('Source: ghc/nofib '+revision+', real/'+family+'.\nOriginal individual notices, fixtures, documentation and symlink targets are retained under upstream/.\nThe canonical common/NofibUtils.hs is retained separately from its per-program symlink.\nRead PROVENANCE.md for authorship, notice gaps, adaptations and validation scope.\nNo additional licence grant is inferred from repository membership or historical correspondence.\n')
  (d/'.gitattributes').write_text('# Preserve exact original notices, inputs and reviewed reference bytes.\nupstream/** -whitespace\n*.reference -whitespace\n*.input -whitespace\ninput.stdin -whitespace\nruntime_files/** -whitespace\n')
  if family=='fluid':
   copy(pin/'real/fluid/fluid.stdin',d/'input.stdin')
   copy(pin/'real/fluid/runtime_files/chan8.dat',d/'runtime_files/chan8.dat')
   copy(p/'fluid-output.reference',d/'output.reference')
  for index,(profile,suffix,timeout,memory)in enumerate([('smoke','faststdin',30,1048576),('normal','stdin',600,4194304),('large','slowstdin',3600,8388608)]):
   if family in ['parser','reptile']:
    src=pin/('real/'+family+'/'+family+'.'+suffix);copy(src,d/(profile+'.input'))
    reference=p/('stage-data/'+profile+('.result'if family=='parser'else'.protocol'))
    assert b'\0'not in reference.read_bytes()
    copy(reference,d/(profile+'.reference'))
    args='500 '+profile+'.input '+digest(reference.read_bytes());expected='500'
    input_files=profile+'.input'
   elif family=='hpg':
    row=json.loads((p/'reviewed-chunks.json').read_text())[index]
    assert row['profile']==profile
    args=' '.join(['100']+list(map(str,row['params']))+row['hashes']);expected='100';input_files='-'
    for chunk in range(3):copy(p/(profile+'-chunk-'+str(chunk)+'.reference'),d/(profile+'-chunk-'+str(chunk)+'.reference'))
   else:
    count=[35,350,1750][index];row=json.loads((p/'reviewed-output.json').read_text())
    args=str(count)+' input.stdin '+row['word64'];expected=str(count)
    input_files='input.stdin,runtime_files/chan8.dat'
   (d/(profile+'.expected')).write_text(expected+'\n')
   row={'benchmark':name,'profile':profile,'upstream':'nofib','source_path':'real/'+family,
     'args':args,'expected':name+'/'+profile+'.expected',
     'sources':','.join(['shared/'+s for s in sources[family]]+[name+'/benchmark.sml','shared/main.sml']),
     'timeout':str(timeout),'memory_kib':str(memory),'tags':'application,'+('numerical,'if family=='fluid'else'')+policy+'-finite-data',
     'input_files':input_files,'result_check':'exact','status':'implemented'}
   assert set(row)==set(header);manifest.append(row)
  new.append(name)
with(suite/'manifest.tsv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=header,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(manifest)
# Translation support has a separate source revision and full licence.
base=private/'nucleic2-originals/base-source'
target=suite/'shared/upstream/ghc-base-4.17.2.0'
for path in ['LICENSE','GHC/Float.hs']:
 copy(base/path,target/path)
# Parser literal support follows the already reviewed Happy Read/Show adaptation.
happy=suite/'happy-lazy/upstream'
for path in ['base/GHC/Show.hs','base/Text/Read/Lex.hs','base/LICENSE']:
 if(happy/path).is_file():copy(happy/path,target/Path(path).relative_to('base'))
(suite/'shared/upstream/nofib-application-support.json').write_text(json.dumps({
 'nofib_revision':revision,'canonical_utility':'common/NofibUtils.hs',
 'ghc_base_version':'4.17.2.0','ghc_revision':'00920f176b0235d5bb52a8e054d89a664f8938fe',
 'support_scope':'GHC literal Read/Show and Float Show; retained original source and full base licence.'},indent=2)+'\n')
print('Registered',len(new),'programs:',','.join(new))
print('Catalogue',len({r['benchmark']for r in manifest}),'programs,',len(manifest),'profiles')
