from pathlib import Path
import csv,shutil,json,hashlib
root=Path.cwd();p=root/'tests/out/benchmarks/graph500-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/graph500seq'
for part in ['sort','kernel','marshal','prototype','driver']:shutil.copy(p/(part+'.sml'),suite/'shared'/('sandmark-graph500-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['graph500-gen','graph500-kernel1','kronecker'];assert not any(r['benchmark']in names for r in rows)
meta={r['profile']:r for r in json.loads((p/'independent-metadata.json').read_text())}
protometa={r['profile']:r for r in json.loads((p/'metadata.json').read_text())['runs']if r['mode']=='prototype'}
allow=[]
for name,mode,source in [('graph500-gen','generate','gen'),('graph500-kernel1','kernel','kernel1_run'),('kronecker','prototype','kronecker')]:
 dest=suite/name;dest.mkdir()
 if mode=='generate':
  upstream=dest/'upstream';upstream.mkdir();shutil.copytree(up,upstream/'graph500seq')
  (upstream/'graph500par').mkdir();shutil.copy(up.parent/'graph500par/graphTypes.mli',upstream/'graph500par/graphTypes.mli')
  shutil.copy(root/'tests/out/benchmarks/upstreams/sandmark/LICENSE.md',upstream/'COLLECTION-LICENSE.md')
  shutil.copytree(p/'ocaml-stdlib',upstream/'ocaml')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n*.marshal -text\n')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  val run = BenchGraph500Driver.{mode}
end
''')
 for profile in ['smoke','normal','large']:
  record=meta[profile]
  if mode=='generate':
   args=f"{record['scale']} {record['edge_factor']}";inputs='-'
   expected=f"{record['edges']} {record['marshal_bytes']} {record['marshal_hash']}"
  elif mode=='kernel':
   file=dest/(profile+'.marshal');shutil.copy(p/(profile+'.marshal'),file)
   args=profile+'.marshal';inputs=args
   expected=f"{record['edges']} {record['vertices']} {record['adjacency_edges']} {record['adjacency_hash']}"
   allow.append(dict(path=str(file.relative_to(root)),bytes=file.stat().st_size,sha256=hashlib.sha256(file.read_bytes()).hexdigest(),kind='generated Graph500 edge-array source data',source_revision='5605805954a00497ed197c930641cddd580e1507',source='benchmarks/graph500seq/generateSeq.ml',origin='OCaml 4.14.1 original serializer with fresh default Random state; seeded gen fixture adapter removes self_init',magic_hex='8495a6be'))
  else:
   entry=protometa[profile];args=f"{entry['scale']} {entry['edge_factor']}";inputs='-'
   data=(p/(profile+'.csv')).read_bytes();h=0
   for b in data:h=(h*31+b)%(2**64)
   expected=f"{2**entry['scale']*entry['edge_factor']} {len(data)} {h:X}"
  (dest/(profile+'.expected')).write_text(expected+'\n')
  sources=['shared/input.sml','shared/ocaml-random.sml']+['shared/sandmark-graph500-'+part+'.sml'for part in ['sort','kernel','marshal','prototype','driver']]+[name+'/benchmark.sml','shared/main.sml']
  tags='graphs,arrays,random,serialization'+(',allocation-lifetimes'if mode=='prototype'else'')
  rows.append(dict(zip(fields,[name,profile,'sandmark',f'benchmarks/graph500seq/{source}.exe',args,f'{name}/{profile}.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),tags,inputs,'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
(suite/'graph500-kernel1/DATA-IDENTITIES.json').write_text(json.dumps(allow,indent=2)+'\n')
(p/'binary-source-data-allowlist.json').write_text(json.dumps(allow,indent=2)+'\n')
data=root/'tests/benchmarks/data/graph500';data.mkdir()
for file in ['smoke.marshal.hex','empty.marshal.hex','boundary.marshal.hex','smoke.edges','smoke.csv']:shutil.copy(p/file,data/file)
(data/'.gitattributes').write_text('*.csv -text -whitespace\n')
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/graph500-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-fft2.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/ocaml-random.sml']+['examples/benchmarks/shared/sandmark-graph500-'+part+'.sml'for part in ['sort','kernel','marshal','prototype','driver']]+['tests/benchmarks/graph500-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(sources)+script[b:]
script=script.replace('fft2','graph500').replace('source transforms, numerical bounds, quoted output and demand checks hold','source graph bytes, numeric weights, sparse order and sorting controls hold')
(root/'tests/benchmarks/check-graph500.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-graph500-parallel.'").replace("{'atom-lazy','atom-strict'}","{'graph500-gen','graph500-kernel1','kronecker'}")
(p/'check-parallel.py').write_text(text)
print('Graph500 imported:370 programs/1102 profiles')
