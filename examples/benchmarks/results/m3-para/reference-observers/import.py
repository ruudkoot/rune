from pathlib import Path
import csv,shutil,hashlib,json
root=Path.cwd();p=root/'tests/out/benchmarks/para-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/spectral/para'
for local,public in [('kernel.sml','nofib-para.sml'),('driver.sml','nofib-para-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('para-')for r in rows)
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='para-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(up,dest/'upstream',ignore=shutil.ignore_patterns('part2'))
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n*.input -text -whitespace\n*.reference -text -whitespace\n')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchParaFn (Bench{policy})
  structure Driver = BenchParaDriverFn (Kernel)
  val run = Driver.run
end
''')
 shutil.copy(p/'small.input',dest/'smoke.input');shutil.copy(p/'small.reference',dest/'smoke.reference')
 shutil.copy(up/'runtime_files/input-data',dest/'full.input');shutil.copy(p/'formatted.reference',dest/'full.reference')
 for profile,repeats,inputName,reference in [('smoke',1,'smoke.input','smoke.reference'),('normal',8,'full.input','full.reference'),('large',40,'full.input','full.reference')]:
  count=(dest/reference).stat().st_size
  (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*count}\n')
  sources=['input','lazy','suspend','stream','nofib-para','nofib-para-driver']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/para',f'{repeats} {inputName} {reference}',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'parsing,higher-order,lists-streams,'+mode,inputName+','+reference,'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/para';data.mkdir()
for pattern in ['small.input','small.reference','anomaly.input','anomaly-*.reference']:
 for file in p.glob(pattern):shutil.copy(file,data/file.name)
shutil.copytree(p/'cases',data/'cases')
(data/'.gitattributes').write_text('*.input -text -whitespace\n*.reference -text -whitespace\ncases/** -text -whitespace\n')
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/para-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-fft2.sh').read_text().replace('fft2','para').replace('source transforms, numerical bounds, quoted output and demand checks hold','source paragraphs, queue rebalancing, exact formatted text and demand checks hold')
# Nested fixtures need stable relative paths and individual data-list rows.
script=script.replace('for file in tests/benchmarks/data/para/*; do basename "$file"; done > "$out/data.txt"',
'''python3 - <<'DATA' > "$out/data.txt"
from pathlib import Path
base=Path("tests/benchmarks/data/para")
for file in sorted(base.rglob("*")):
    if file.is_file() and file.name != ".gitattributes":
        print(file.relative_to(base))
DATA''')
(root/'tests/benchmarks/check-para.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-para-parallel.'").replace("{'atom-lazy','atom-strict'}","{'para-lazy','para-strict'}")
(p/'check-parallel.py').write_text(text)
with(suite/'source-variants.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
for filename,language,role,reason,notice in [
 ('c++/Part2.C','C++','historical implementation','distinct sequential C++ formatter with bounded word buffers and command-line line width remains outside the initial SML/Haskell/OCaml executable set; retain source and companion Para/Queue/Thin modules as a future candidate; historical headers require a reviewed build adaptation','no separate source redistribution notice stated; author attribution comes from the parent article'),
 ('c++/part2','ELF i386','compiled artifact','exclude pinned compiled executable from imported sources and never execute it; retain this identity and its C++ sources instead of allowing executable artifacts','no separate executable notice stated')]:
 file=up/filename;rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','spectral/para','spectral/para/'+filename,file.stem,language,role,'Oege de Moor;Jeremy Gibbons',hashlib.sha256(file.read_bytes()).hexdigest(),'exclude',reason,notice])))
with(suite/'source-variants.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
print('Para imported; suite 362 programs /1078 profiles')
