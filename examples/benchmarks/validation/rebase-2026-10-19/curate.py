from pathlib import Path
import json,subprocess,csv,re,hashlib,shutil
root=Path.cwd();p=Path(__file__).resolve().parent;suite=root/'examples/benchmarks'
a=json.loads((p/'acceptance-exit.json').read_text());assert a['exit']==2,a
full=(p/'acceptance.log').read_text()
assert 'RESULT: FAIL 16524 of 16524 tests (2 SKIP, 16521 PASS, 1 FAIL)'in full
assert [line for line in full.splitlines()if line.startswith('FAIL make/')]==['FAIL make/test-opt: exit 2']
assert 'exp.record_captured_virtual.rbc: unsupported bytecode version'in full
assert json.loads((p/'optimizer-recheck-exit.json').read_text())['exit']==0
focused=json.loads((p/'focused-exits.json').read_text());assert len(focused)==5 and all(x['exit']==0 for x in focused),focused
assert json.loads((p/'application-catalog-exit.json').read_text())['exit']==0
assert json.loads((p/'provenance-final-exit.json').read_text())['exit']==0
subject=json.loads((p/'subject.json').read_text())
dest=suite/'validation/rebase-2026-10-19';dest.mkdir(exist_ok=True)
(dest/'.gitattributes').write_text('# Exact command and validation evidence.\n** -whitespace\n')
for f in p.iterdir():
 if f.is_file()and f.suffix not in ['.rbc','.nul']and f.name not in ['pre-rebase-vm-version.h','PROGRESS.md']:
  data=f.read_bytes()
  if b'\0'not in data:shutil.copyfile(f,dest/f.name)
for name in ['coverage','provenance','provenance-final','application-catalog']:
 log=(p/(name+'.log')).read_text()
 found=re.findall(r'\((/[^)\n]+)\)',log)
 if found:
  folder=Path(found[-1])
  for f in folder.rglob('*'):
   if not f.is_file()or any(x in ['MLB','.cm','.git']for x in f.parts):continue
   if f.suffix in ['.rbc','.o','.hi','.exe','.heap','.state','.cmx','.cmi','.cmo','.a','.pyc']:continue
   data=f.read_bytes()
   if b'\0'in data or data.startswith((b'\x7fELF',b'MZ',b'!<arch>\n')):continue
   target=dest/name/f.relative_to(folder);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,target)
for label,logname in [('full-suite','acceptance.log'),('optimizer-recheck','optimizer-recheck.log')]:
 content=(p/logname).read_text()
 matches=re.findall(r'events in ([^,\n]+), summary in ([^\n]+)',content)
 assert matches,(label,'missing runner evidence')
 events,summary=map(Path,matches[-1])
 target=dest/label;target.mkdir(exist_ok=True)
 for f in [events,summary,*events.parent.glob('*.json'),*events.parent.glob('*.tsv')]:
  if f.is_file()and b'\0'not in f.read_bytes():shutil.copyfile(f,target/f.name)
(suite/'validation/rebase-2026-10-19.md').write_text(f"""# Benchmark rebase onto master, 2026-10-19

Rebased the benchmarks branch from {subject['old_tip']} onto
origin/master {subject['upstream']}. All 93 branch commits were replayed.
Their author identities, complete messages and full model co-author trailers
are preserved; [the mapping](rebase-2026-10-19/commit-map.tsv) identifies every
rewritten commit. A local recovery ref is
backup/benchmarks-before-rebase-20261019-a72c57061.

Master's three Rune-authored latency workloads are retained alongside the
507 imported programs. The current catalogue contains 510 programs and 1482
profiles. The external source inventory still has 861 entries and 38
companions; Rune-authored source files are checked locally rather than
invented as external upstream entries.

The conflicts retain both sets of README rows/sections, both SML/NJ
bug-report histories, current stack-VM catalogue commands, the benchmark
metadata checks and selected-tool provenance. Master's count budgets and
SAT source-encoding adaptations are retained. The existing archived result
tree is unchanged: its Git tree identity before and after the rebase is
2b448e4ac166c9e472fb68b23e39c1e7b1bac847.

The first acceptance attempt used the existing managed mlkit alias, which
still selected 4.7.23, and stopped at its internal
Impossible: Mul: diffef failed crash while building Rune. Master pins 4.7.25.
The retry uses the already-installed 4.7.25 compiler/library through explicit
MLKIT and MLKIT_LIB arguments. Thirteen generated project cache directories
were preserved outside the build paths before rebuilding; tracked sources
and the global host alias were unchanged. The failed attempt remains in the
evidence alongside the 4.7.25 run and optimizer recheck.

The 4.7.25 full suite completed after {a['elapsed_seconds']:.1f} seconds
with one optimizer failure: an old tests/out/exp.record_captured_virtual.rbc
still used bytecode version 5 while current tools require version 6.
The file belonged to a removed fixture and was not regenerated. Its exact
bytes and SHA-256 were preserved outside the legacy optimizer glob; no
source or expected result changed. The affected make/test-opt gate and its
560-job dependency rerun then pass. The original full-run exit and failed
gate remain recorded; this is not presented as a single clean full-run exit.

The follow-up integration checks require real source files for built-in
workloads, stage them for the portable coverage regressions, load the
catalogue with its stack VM, and fingerprint the current register/stack
payload names. All ordered runnable SML sources contain ASCII bytes, so
master's source-mode default needs no translation workaround.

| Check | Recorded outcome |
|---|---|
| Full repository acceptance | All 16524 jobs ran with MLKit 4.7.25: 16521 PASS, two expected SKIP and one obsolete-bytecode failure; original exit 2 retained. The affected optimizer gate and its 560-job rerun pass after generated-output isolation. |
| Routine benchmark smoke | All 1482 profiles validate; the bounded Rune smoke set passes. |
| Portable coverage regression | Seven assertions pass on Rune, MLton, legacy SML/NJ and Poly/ML, including the missing built-in-source rejection. |
| Application catalogue | The independent Parser semantic checks pass on Rune at O0/O2 through the corrected catalogue path. |
| Selected-tool provenance | Foreign compiler revision/dirty state, actual Basis, current stack/register and legacy register payloads, and unknown launchers remain distinct. |
| Latency oracle | The independent expected-result oracle passes. |
| Latency smoke and normal | All three workloads pass both profiles on Rune's stack configuration. |

[Commands, subjects, exit codes and raw logs](rebase-2026-10-19/) preserve
the actual validation epoch. The metadata-only legacy-payload follow-up has its own final regression and source identities.\nThe previous import-wave evidence remains
historical evidence for its recorded sources and compiler configurations;
this rebase does not claim a fresh all-program, all-host sweep or a new
performance comparison. Timing thresholds remain outside make check.
""")
p2=suite/'validation.md';text=p2.read_text()
assert '## Rebase onto current master, 2026-10-19'not in text
text+="""
## Rebase onto current master, 2026-10-19

[The integration record](validation/rebase-2026-10-19.md) preserves all 93
benchmark commits and the existing archived result bytes while retaining
master's three latency workloads, current VM commands, count budgets and
source-encoding adaptations. The catalogue now has 510 programs and 1482
profiles. The full suite records 16521 passes, two expected skips and one stale generated
bytecode failure; the affected optimizer gate and its 560-job dependency
rerun pass after preserving and isolating that obsolete output. Routine
smoke, seven coverage assertions on four SML implementations, provenance
regressions, the latency oracle and all three latency smoke/normal profiles
pass on the recorded rebased subject.
"""
p2.write_text(text)
print('Rebase evidence and current-master validation recorded')
