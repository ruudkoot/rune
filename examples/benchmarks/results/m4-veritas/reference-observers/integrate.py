from pathlib import Path
import csv,hashlib,json,shutil,subprocess,re
root=Path.cwd();suite=root/'examples/benchmarks';p=Path(__file__).resolve().parent
pin=root/'tests/out/benchmarks/pinned/nofib';revision='b7391df4540ac8b11b35e1b2e2c15819b5171798'
assert subprocess.check_output(['git','-C',str(pin),'rev-parse','HEAD'],text=True).strip()==revision
def copy(src,dest):
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
def table(path,header,rows):
 with path.open('w',newline='')as f:
  w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(header);w.writerows(rows)
kernel=(p/'kernel.sml').read_text().replace('BenchVeritasFn','BenchNofibVeritasFn')
(suite/'shared/nofib-veritas-kernel.sml').write_text(kernel)
(suite/'shared/nofib-veritas-check.sml').write_text((p/'check.sml').read_text().replace('BenchVeritasCheckFn','BenchNofibVeritasCheckFn'))
manifest=list(csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t'));header=list(manifest[0])
report=json.loads((p/'reviewed-output.json').read_text())
for policy,delay in [('lazy','BenchNeed'),('strict','BenchStrict')]:
 name='veritas-'+policy;d=suite/name;d.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchNofibVeritasFn('+delay+')\n structure Check=BenchNofibVeritasCheckFn(Kernel)\n val run=Check.run\nend\n')
 identities=[]
 for raw in subprocess.check_output(['git','-C',str(pin),'ls-files','-z','--','real/veritas']).split(b'\0'):
  if not raw:continue
  path=raw.decode();src=pin/path;relative=Path(path).relative_to('real/veritas')
  if src.is_symlink():
   data=src.readlink().as_posix().encode();target=d/'upstream'/(relative.as_posix()+'.link')
   target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);kind='symlink-target'
  else:data=src.read_bytes();target=d/'upstream'/relative;copy(src,target);kind='upstream-file'
  identities.append([path,str(target.relative_to(d)),kind,len(data),hashlib.sha256(data).hexdigest()])
 src=pin/'common/NofibUtils.hs';data=src.read_bytes();copy(src,d/'upstream/common/NofibUtils.hs')
 identities.append(['common/NofibUtils.hs','upstream/common/NofibUtils.hs','canonical-shared-utility',len(data),hashlib.sha256(data).hexdigest()])
 table(d/'UPSTREAM-IDENTITIES.tsv',['source_path','archived_path','kind','bytes','sha256'],identities)
 (d/'NOTICE').write_text('Source: ghc/nofib '+revision+', real/veritas.\nOriginal README correspondence is signed Gareth; no general program redistribution notice is stated.\nRetain individual original files, inputs, notices and documentation under upstream/.\nThe canonical common/NofibUtils.hs is retained separately from the directory symlink target.\nNo separate general redistribution grant is inferred from suite membership.\nSee PROVENANCE.md for adaptations, authorship, source limitations and validation scope.\n')
 (d/'.gitattributes').write_text('# Exact source and reviewed input/reference bytes.\nupstream/** -whitespace\n*.reference -whitespace\n*.input -whitespace\nruntime_files/** -whitespace\n')
 
 for profile,suffix,limit,memory in [('smoke','faststdin',30,1048576),('normal','stdin',600,4194304),('large','slowstdin',3600,8388608)]:
  copy(pin/'real/veritas/veritas.stdin',d/(profile+'.input'))
  copy(p/'full-protocol.reference',d/'protocol.hex')
  (d/(profile+'.expected')).write_text(str({'smoke':400,'normal':4000,'large':20000}[profile])+'\n')
  files=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml','shared/nofib-veritas-kernel.sml','shared/nofib-veritas-check.sml',name+'/benchmark.sml','shared/main.sml']
  row=dict(benchmark=name,profile=profile,upstream='nofib',source_path='real/veritas',
    args=str({'smoke':400,'normal':4000,'large':20000}[profile])+' '+profile+'.input '+report['word64'],expected=name+'/'+profile+'.expected',
    sources=','.join(files),timeout=str(limit),memory_kib=str(memory),
    tags='application,proof-assistant,parsing,symbolic,closures,'+policy+'-finite-data',
    input_files=profile+'.input',result_check='exact',status='implemented')
  assert set(row)==set(header);manifest.append(row)
with(suite/'manifest.tsv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=header,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(manifest)
provenance="# nofib Veritas provenance\n\n## Algorithm and workload\n\nExecute the original scripted proof-editor session for the Veritas design\nlogic. Tokenize and parse a functional concrete syntax, manipulate terms,\ndeclarations and signatures, build proof trees, apply tactics, track completion,\nrender the original X-interface requests and compute their modular hash.\nThe maintained nofib driver repeats the same session 400/4000/20000 times.\n\n## History, authorship, revision and aliases\n\nUse nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/veritas.\nThe README is a letter to Kevin signed Gareth about running this program\non GRIP. Retain that stated role without assigning an unverified individual\ncopyright or inferring a redistribution grant. Individual original source,\ncomments, input files and notices are archived with exact identities.\nCanonical common/NofibUtils.hs and the directory symlink target are separate.\n\nHanna, Daeche and Howells, Implementation of the Veritas Design Logic (1992),\nis related implementation literature, identified by the authors' institution.\nThat bibliography is not a source identity for this precise historical\nsnapshot, nor does the README alone identify every author or porting role.\nThe name identifies this historical nofib program.\n\n## Known variants\n\nveritas-lazy memoizes finite syntax, term fields, attributes, proof trees and\nrequest characters. veritas-strict evaluates those finite attributes eagerly.\nBoth preserve memoized state/output control, suspended action results, unused\npair components, finite token control and infinite response/identifier\nstreams. Both match the complete original session and all supplemental\nprotocol/editor-outcome controls.\n\nThe interface is a pure byte protocol over supplied scripted input. It does\nnot require a running X server or a network connection. Edlib's error\nhandlers are ordinary result/state combinators; no runtime effect-handler\nfeature is required.\n\n## Translation and adaptations\n\nRetain the original scanner, precedence algorithm, binders, source attributes,\nsignature lookup, de Bruijn-style indices, shifting, substitution,\nterm/type construction, proof rules, tree navigation, persistent history,\ntactic validation and output request order. Keep the live command table and\noriginal argument forms. Keep source optional database restore stubs and\nthe original commented inactive code as historical source; do not introduce\nfilesystem/database behavior that the selected driver does not execute.\n\nUse explicit SML97 algebraic data, persistent lists, memoized delays and pure\nstate/output functions. Action results and paired return components remain\nsuspended even in the strict-data variant: the original finish result and\nsome error values must stay unforced when only the request stream is needed.\nReset identifiers to one and responses to zero for each fresh session,\nsharing the raw input characters across repetitions. Global protocol escapes\nand delayed derived-logic schemas preserve their separate sharing.\n\nKernel indices and counters use native signed Int. All selected input\nnumerals, signature depths, goal identifiers and repetition counts fit signed\n31-bit Int; review that bound before adding larger or different inputs.\nThis is the selected benchmark's explicit width assumption, not a claim about\nunrestricted 64-bit user programs. Hash arithmetic is explicitly modular\nWord64, matching the pinned 64-bit GHC result. IntInf is used only for signed\nhash formatting. No numerical tolerance or arithmetic widening is introduced.\nInput and request characters are bytes, matching original binary-mode input.\n\nPreserve observed source quirks and stubs, including duplicate Share-index\ncomparison, the retained declaration tail in map_data, the first conditional\nbranch reused in propositional evaluation, the constructor-type and eta\nstubs, self-signature comparison in subterm rewriting and the shadowed third\ndisjunction parameter. The suite checks this program's behavior; it does not\ncertify the historical proof kernel's logical soundness.\n\n## Compiler and runtime questions\n\nHigher-order state/output combinators, closures, immutable terms and trees,\nsharing, unused result fields, recursive parser construction, byte rendering,\npartial applications and object lifetimes are source-based diagnostic\nquestions. Their performance effects remain hypotheses until measurements\nestablish them. Strict data may force proof objects that lazy request\ngeneration leaves suspended; policies are separately named.\n\nSML/NJ image export evaluates declarations during compilation. Record that\nphase separately from fresh execution and interpret them together. Repeated\nexecution retains global sharing and does not imply a steady state.\n\n## Inputs, validation and references\n\nAll profiles use the original 196-byte veritas.stdin, identical to grip-in.\nThe original main computes a 1391-byte request stream with SHA-256\n91ae6ea6fb1188a5f90e69bdaeb0f7c3d3b5d5d6f1bf6141db14f1883bbe5865.\nIts Word64 digest is CD1FC6B0A4675CFB, signed -3665993109681513221.\nAll 400/4000/20000 lines of the pinned stdout fixtures agree with that value.\nEach portable repetition validates the complete request-stream hash before\nprinting it; the shared suite driver also validates the repetition count.\n\nThe upstream Makefile explicitly questions how much of the prover this\nsingle input exercises. Keep that diagnostic limitation. Supplemental\nsemantic controls independently compare tokenization, parsed rendering,\nprotocol primitives, ignored return values, request streams and final editor\noutcomes against the original GHC functions. They include failures and invalid\nproof outcomes produced by the original, recorded as such. Timed profiles\nretain the original forcing of requests; extra proof inspection belongs to\nthe semantic target.\n\nRaw request streams contain NUL bytes. Store the independent request\nreferences as reviewed ASCII hexadecimal, with byte identities and decoding\nin the SML tests. Original inputs and notices retain their exact bytes.\nThe [pinned suite sources](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/veritas)\nestablish exact workload ancestry. The [University of Kent publication record](https://www.cs.kent.ac.uk/pubs/1992/427/index.html)\nidentifies Implementation of the Veritas Design Logic (1992) as related\nliterature. Private source comparisons and both 400-repeat smoke drivers pass.\nPublic host/profile, count and repository acceptance gates are pending.\n"

for name in ['veritas-lazy','veritas-strict']:(suite/name/'PROVENANCE.md').write_text(provenance)
readme=suite/'README.md';s=readme.read_text()
first=s.index('\n## ',s.index('| Name |'))
rows=''
for policy in ['lazy','strict']:
 name='veritas-'+policy
 rows+='| ['+name+'](#'+name+') | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/'+revision+'/real/veritas) | Execute and validate a scripted proof-editor session using dependent-type logic and immutable proof trees. |\n'
s=s[:first]+'\n'+rows+s[first:]
s=s.replace('\n\n| [veritas-lazy]','\n| [veritas-lazy]')
for name in ['veritas-lazy','veritas-strict']:
 s+='\n## '+name+'\n\n'+provenance.split('## Algorithm and workload\n\n')[1].split('\n## History')[0]+'\n\nSee ['+name+'/PROVENANCE.md]('+name+'/PROVENANCE.md) for history,\nvariants, adaptations, runtime questions, inputs, checks and references.\nPublic host/profile validation is pending.\n'
readme.write_text(s)
f=root/'docs/plans/benchmarks.md';s=f.read_text().replace('505 programs and 1467 profiles','507 programs and 1473 profiles')
s=s.replace('Veritas is a private port with original request-stream and editor-outcome\nagreement; its public registration and validation remain pending.',
'''Veritas now registers lazy and strict ports after independent request-stream
and editor-outcome agreement and private 400-repeat smoke checks. Its public
host/profile, count and acceptance gates remain pending; M4 is still in progress.''')
f.write_text(s)
f=suite/'literature.md';f.write_text(f.read_text()+'''
## Veritas proof-editor application

Hanna, Daeche and Howells, [Implementation of the Veritas Design Logic](https://www.cs.kent.ac.uk/pubs/1992/427/index.html),
1992, is related implementation literature identified by the authors'
University of Kent record. The pinned nofib source and README identify the
actual historical workload and input; the paper record alone does not
establish this exact source snapshot's authorship or release. Source analysis
suggests diagnostics involving dependent-type terms, signatures, attributes,
state/output combinators, persistent proof trees and lazy result fields.
The upstream Makefile warns that its fixed script exercises a limited part
of the prover; preserve that limit when interpreting measurements.
''')
print('registered 507 programs and 1473 profiles; Veritas public gates pending')
