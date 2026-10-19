from pathlib import Path
import csv,hashlib,json,shutil,subprocess
root=Path.cwd();suite=root/'examples/benchmarks';p=Path(__file__).resolve().parent
pin=root/'tests/out/benchmarks/pinned/nofib';revision='b7391df4540ac8b11b35e1b2e2c15819b5171798'
assert subprocess.check_output(['git','-C',str(pin),'rev-parse','HEAD'],text=True).strip()==revision
def copy(src,dest):
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
def table(path,header,rows):
 with path.open('w',newline='')as f:
  w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(header);w.writerows(rows)
kernel=(p/'kernel-port.sml').read_text().replace('BenchAnnaFn','BenchNofibAnnaFn')
(suite/'shared/nofib-anna-kernel.sml').write_text(kernel)
(suite/'shared/nofib-anna-check.sml').write_text((p/'check.sml').read_text().replace('BenchAnnaCheckFn','BenchNofibAnnaCheckFn'))
manifest=list(csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t'));header=list(manifest[0])
reports=json.loads((p/'reviewed-reports.json').read_text())
for policy,delay in [('lazy','BenchNeed'),('strict','BenchStrict')]:
 name='anna-'+policy;d=suite/name;d.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchNofibAnnaFn('+delay+')\n structure Check=BenchNofibAnnaCheckFn(Kernel)\n val run=Check.run\nend\n')
 identities=[]
 for raw in subprocess.check_output(['git','-C',str(pin),'ls-files','-z','--','real/anna']).split(b'\0'):
  if not raw:continue
  path=raw.decode();src=pin/path;relative=Path(path).relative_to('real/anna')
  if src.is_symlink():
   data=src.readlink().as_posix().encode();target=d/'upstream'/(relative.as_posix()+'.link')
   target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);kind='symlink-target'
  else:data=src.read_bytes();target=d/'upstream'/relative;copy(src,target);kind='upstream-file'
  identities.append([path,str(target.relative_to(d)),kind,len(data),hashlib.sha256(data).hexdigest()])
 src=pin/'common/NofibUtils.hs';data=src.read_bytes();copy(src,d/'upstream/common/NofibUtils.hs')
 identities.append(['common/NofibUtils.hs','upstream/common/NofibUtils.hs','canonical-shared-utility',len(data),hashlib.sha256(data).hexdigest()])
 table(d/'UPSTREAM-IDENTITIES.tsv',['source_path','archived_path','kind','bytes','sha256'],identities)
 (d/'NOTICE').write_text('Source: ghc/nofib '+revision+', real/anna.\nAnna 0.400 main banner: Copyright (c) Julian Seward 1992.\nRetain individual original files, inputs, lattice table, notices and documentation under upstream/.\nThe canonical common/NofibUtils.hs is retained separately from the directory symlink target.\nNo separate general redistribution grant is inferred from suite membership.\nSee PROVENANCE.md for adaptations, authorship, auxiliary-program disposition and validation scope.\n')
 (d/'.gitattributes').write_text('# Exact source and reviewed input/reference bytes.\nupstream/** -whitespace\n*.reference -whitespace\n*.input -whitespace\nruntime_files/** -whitespace\n')
 copy(pin/'real/anna/runtime_files/anna_table',d/'runtime_files/anna_table')
 for profile,suffix,limit,memory in [('smoke','faststdin',30,1048576),('normal','stdin',600,4194304),('large','slowstdin',3600,8388608)]:
  copy(pin/('real/anna/anna.'+suffix),d/(profile+'.input'))
  copy(p/('full-'+profile+'.reference'),d/(profile+'.reference'))
  (d/(profile+'.expected')).write_text('100\n')
  files=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml','shared/signed64.sml','shared/nofib-anna-kernel.sml','shared/nofib-anna-check.sml',name+'/benchmark.sml','shared/main.sml']
  row=dict(benchmark=name,profile=profile,upstream='nofib',source_path='real/anna',
    args='100 '+profile+'.input '+reports[profile]['word64'],expected=name+'/'+profile+'.expected',
    sources=','.join(files),timeout=str(limit),memory_kib=str(memory),
    tags='application,compiler,parsing,type-inference,abstract-interpretation,'+policy+'-finite-data',
    input_files=profile+'.input,runtime_files/anna_table',result_check='exact',status='implemented')
  assert set(row)==set(header);manifest.append(row)
with(suite/'manifest.tsv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=header,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(manifest)
provenance='''# nofib Anna provenance

## Algorithm and workload

Anna 0.400 parses a typed functional Core language, lambda-lifts definitions,
infers types, eta-abstracts and computes strictness abstractions over finite
domains. It builds constructor inverses, uses Hunt-style frontier search,
finds recursive fixed points and generalizes polymorphic functions through
embedding/closure compositions. Render the complete original analysis report,
including input, inferred types, search evaluations, domains and results.
Preserve 100 complete analyses per invocation and reopen the lattice table
on every repetition, as the original driver does.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/anna.
The original banner identifies Julian Seward and Copyright (c) 1992.
README calls this release 0.400. Individual files, source input programs,
original output fixtures, lattice database and build documentation are
retained exactly, with source identities. No separate general redistribution
permission is stated in those notices. Canonical common/NofibUtils.hs has its
own source identity; the per-directory symlink target is recorded separately.

Monster.hs is a separately built auxiliary lattice enumerator, explicitly
described as outside the analyser in its heading and the original README.
Its source and Monstermakefile remain in upstream/. It is not a second
measured Anna implementation or a required runtime generator. Its explicit
inventory disposition is part of the remaining closure audit.

## Known variants

anna-lazy memoizes finite data, syntax trees, domains, routes, frontiers and
report characters. anna-strict evaluates those finite attributes eagerly.
Both retain memoized control, cyclic lexer EOF, recursive parser builders,
demand-sensitive branches, bounded producers and unused source arguments.
Both match the complete original report on all three source inputs.
Their evaluation and allocation behavior are separately named.

## Translation and adaptations

Keep the source algorithms and orders: insertion sort, source Cartesian
product order, dependency grouping, substitution composition, type-name
supply splitting, frontier minimum/maximum insertion, randomized edge choice,
Dijkstra tie selection, successive lattice sizing, live-before-safe fixed
points, inverse construction and original report formatting. Keep the
source's special empty lifted domains and constructor/CAF conventions.

Source Int arithmetic uses explicit modular 64-bit words with signed
division, order and rendering. This includes type-name supplies and the
Schrage two-seed random stream whose constants exceed signed 31-bit Int.
Native Int is restricted to bounded byte/tag/list-adapter operations.
Integer result formatting uses IntInf only to express signed output; the
analysis does not widen arithmetic to arbitrary precision. There is no
floating-point approximation or numerical tolerance.

Translate source algebraic data and lists to explicit portable delays.
Keep unused inherited-frontier arguments as functions, including the original
unforced panic branch; eager finite data must not evaluate that control.
Keep the source's min1 reconstruction from the original max0 in Baraki
normalization. Preserve first-success parser behavior, let-bound substitutions
and source counter/ordering conventions. Source pair/tuple patterns become
closed SML97 types. Portable indentation uses the original Iseq/Oseq
continuation algorithm; small literal block lists compose append functions.

The fixed profiles use the original no-flag settings: polymorphic and
monomorphic limits 10000, lower lattice limit 0, upper 1000000, scale 20.
The driver maps repetitions and input filenames explicitly and validates each
complete-report hash before printing its signed value. It shares raw input
characters across repetitions and reads a fresh table each time. It exposes
the selected benchmark profiles rather than the analyser's entire optional
command-line interface. Unused AVL-tree utilities, the standalone Monster
main and unused command-line parsing are retained as original source, not
claimed as executed analysis work.

The Core operator parallel-or is an abstract truth-table value. It does not
execute threads and does not require a parallel Rune runtime. No compiler or
runtime feature is introduced to support the port.

## Compiler and runtime questions

Higher-order parser calls, recursive type substitution, finite-domain
representation, retained sharing, frontier search, polymorphic
specialization and report construction are diagnostic questions supported by
source inspection. Their performance effects remain hypotheses until
measured. Semantic agreement does not establish a speedup.

SML/NJ exported images execute declarations during compilation. Global
finite-data initialization and memoized streams can enter that phase.
Report compilation and fresh-process execution separately. Repeated
in-process execution retains global sharing and does not imply steady state.

## Inputs, validation and references

Smoke/normal/large use anna.faststdin, anna.stdin and anna.slowstdin, with
631/3246/9060 bytes. Preserve 100 repetitions for each profile and the complete
nine-entry runtime_files/anna_table. The resulting reports have
2810/28800/86941 bytes. Independent original report hashes agree with all
100 lines of each pinned stdout fixture: -887277049712337739,
2911885587254673792 and 1779591958989696265.

Original GHC functions independently establish complete parsing, dependency,
lambda-lifting, type-inference, eta and analysis observations. The complete
11/184/601 analysis records agree in both policies. Further observations
cover abstract routes/order/lattice operations/successors/predecessors,
lattice normalization and sizing, RNG, shortest-path ties, complete frontier
representations and memo order. All six complete formatted reports match
byte for byte. Both 100-repeat smoke drivers pass privately. Public
host/profile, count and acceptance checks are pending.

The original source establishes implementation ancestry. Baraki's
[Abstract Interpretation of Polymorphic Higher-Order Functions (1993)](https://theses.gla.ac.uk/74619/)
provides primary background on the embedding/closure approach. Source files
BarakiConc3 and BarakiMeet explicitly identify that technique. Claims about
the port's actual computation are checked against the pinned program.
'''
for name in ['anna-lazy','anna-strict']:(suite/name/'PROVENANCE.md').write_text(provenance)
readme=suite/'README.md';s=readme.read_text();first=s.index('\n## ',s.index('| Name |'))
# The first section follows the overview table; keep new rows inside it.
rows=''
for policy in ['lazy','strict']:
 name='anna-'+policy
 rows+='| ['+name+'](#'+name+') | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/'+revision+'/real/anna) | Infer types and compute polymorphic strictness frontiers for functional Core programs. |\n'
s=s[:first]+'\n'+rows+s[first:]
for name in ['anna-lazy','anna-strict']:
 s+='\n## '+name+'\n\n'+provenance.split('## Algorithm and workload\n\n')[1].split('\n## History')[0]+'\n\nSee ['+name+'/PROVENANCE.md]('+name+'/PROVENANCE.md) for history,\nvariants, adaptations, runtime questions, inputs, checks and references.\nPublic host/profile validation is pending.\n'
readme.write_text(s)
f=root/'docs/plans/benchmarks.md';s=f.read_text().replace('503 programs and 1461 profiles','505 programs and 1467 profiles')
s=s.replace('Anna is a private\npartial port with complete report agreement on the three source inputs;\nVeritas is not yet ported. Neither appears as a runnable benchmark.',
'''Anna now registers lazy and strict ports after complete report agreement
on all three source inputs and private 100-repeat smoke checks. Its public
host/profile, count and acceptance gates are pending. Veritas is not yet ported.''')
f.write_text(s)
f=suite/'literature.md';f.write_text(f.read_text()+'''
## Anna strictness analysis

Baraki, [Abstract Interpretation of Polymorphic Higher-Order Functions](https://theses.gla.ac.uk/74619/),
PhD thesis, University of Glasgow, 1993, develops embedding/closure-based
relations between polymorphic instances. Anna's pinned BarakiConc3 and
BarakiMeet sources explicitly identify that approach. The thesis supplies
theoretical background; the original GHC program establishes the selected
workload and its expected reports. Frontier representation, fixed-point
iteration, sharing and polymorphic instantiation are source-based diagnostic
hypotheses until benchmark measurements establish an effect.
''')
print('registered 505 programs and 1467 profiles; Anna public gates pending')
